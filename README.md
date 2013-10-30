# Massive

[![build status][1]][2]
[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/dtmtec/massive/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

[1]: https://travis-ci.org/dtmtec/massive.png
[2]: http://travis-ci.org/dtmtec/massive

Massive gives you a basic infrastructure to parallelize processing of large files and/or data using Resque, Redis and MongoDB.

## Installation

Add this line to your application's Gemfile:

    gem 'massive'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install massive

## Requirements

If you want notifications using [Pusher][http://pusher.com], you'll need to add `pusher-gem` to your Gemfile. Also, if you'd like these notifications to be sent in less than one second intervals you'll need to use 2.6 version of Redis.

## Usage

Massive gives you a basic model structure to process data, either coming from a file or from some other source, like a database. It has three basic concepts:

* __Process__: defines the set of steps and control their execution.
* __Step__: a step of the process, for example, when processing a CSV file you may want to gather some info of the file, them read the data from the file and import it to the database, and later perform some processing on that data. In this scenario you would create 3 steps, each step would split the processing into smaller jobs.
* __Job__: here lies the basic processing logic, iterating through each item from the data set reserved for it, and them process the item. It also updates the number of processed items, so you can poll the jobs about their progress.

The main usage would consist in subclassing `Massive::Step` and `Massive::Job` to add the required logic for your processing.

For example, suppose you want to perform an operation on a model, for example, cache the number of friends a `User` has on a social network. Let's suppose that we have 100 thousands users in the database, so this would probably take some time, so we want to do it in background.

We just need one step for it, and we will call it `CacheFriendsStep`:

```ruby
  class CacheFriendsStep < Massive::Step
    # here we tell it how to calculate the total number of items we want it to process
    calculates_total_count_with { User.count }

    # we define the job class, otherwise it would use the default, which is Massive::Job
    job_class 'CacheFriendsJob'
  end
```

Then we define the job class `CacheFriendsJob`, redefining two methods `each_item` and `process_each`. The first one is used to iterate through our data set, yielding the given block on each pass. Note that it uses the job offset and limit, so that the job can be parallelized. The last one is used to actually process an item, receiving its index within the job data set.

```ruby
  class CacheFriendsJob < Massive::Job
    def each_item(&block)
      User.offset(offset).limit(limit).each(&block)
    end

    def process_each(user, index)
      user.friends_count = user.friends.count
    end
  end
```

Now we just create a process, and add the `CacheFriendsStep` to it, then enqueue the step:

```ruby
  process = Massive::Process.new
  process.steps << CacheFriendsStep.new
  process.save

  process.enqueue_next
```

Now the `CacheFriendsStep` is enqueued in the Resque queue. When it is run by a Resque worker it will split the processing into a number of jobs based on the step `limit_ratio`. This  `limit_ratio` could be defined like this:

```ruby
  class CacheFriendsStep < Massive::Step
    # here we tell it how to calculate the total number of items we want it to process
    calculates_total_count_with { User.count }

    # we define the job class, otherwise it would use the default, which is Massive::Job
    job_class 'CacheFriendsJob'

    # defining a different limit ratio
    limit_ratio 2000 => 1000, 1000 => 200, 0 => 100
  end
```

What this means is that when the number of items to process is greater or equal than 2000, it will split jobs making each one process 1000 items. If the number of items is less than 2000 but greater than 1000, it will process 200 items each. If the number of items is less than 1000, it will process 100 items each.

The default limit ratio is defined like this: `3000 => 1000, 0 => 100`. When its greater than or equal to 3000, process 1000 items each, otherwise, process 100.

For the above example, it would create `100000 / 1000 == 100` jobs, where the first one would have an offset of 0, and a limit of 1000, the next one an offset of 1000 and a limit of 1000, and so on.

With 100 jobs in a Resque queue you may want to start more than one worker so that it can process this queue more quickly.

Now you just need to wait until all jobs have been completed, by polling the step once in a while:

```ruby
  process.reload
  step = process.steps.first

  step.processed            # gives you the sum of the number of items processed by all jobs
  step.processed_percentage # the percentage of processed items based on the total count
  step.elapsed_time         # the elapsed time from when the step started processing until now, or its duration once it is finished
  step.processing_time      # the sum of the elapsed time for each job, which basically gives you the total time spent processing your data set.
```

You can check whether the step is completed, or started:

```ruby
  step.started?     # true   when it has been started
  step.completed?   # false  when it has been completed, i.e., there is at least one job that has not been completed
```

### Retry

When an error occurs while processing an item, it will automatically retry it for a number of times, giving an interval. By default it will retry 10 times with a 2 second interval. This is very useful when you'd expect some external service to fail for a small period of time, but you want to make sure that you recover from it, without the need to retry the entire job processing.

If the processing of a single item fails for the maximum number of retries the exception will be raised again, making the job fail. The error message will be stored and can be accessed through `Massive::Job#last_error`. It will also record the time when the error occurred.

You can change retry interval and the maximum number of retries if you want:

```ruby
  class CacheFriendsJob < Massive::Job
    retry_interval 5
    maximum_retries 3

    def each_item(&block)
      User.offset(offset).limit(limit).each(&block)
    end

    def process_each(user, index)
      user.friends_count = user.friends.count
    end
  end
```

### File

One common use for __Massive__ is to process large CSV files, so it comes with `Massive::FileProcess`, `Massive::FileStep` and `Massive::FileJob`. A `Massive::FileProcess` embeds one `Massive::File`, which has a URL to a local or external file, and a [file processor](https://github.com/dtmtec/file_processor).

With this structure you can easily import users from a CSV file:

```ruby
  class ImportUsersStep < Massive::FileStep
    job_class 'ImportUsersJob'
  end

  class ImportUsersJob < Massive::FileJob
    def process_each(row, index)
      User.create(row)
    end
  end

  process = Massive::FileProcess.new(file_attributes: { url: '/path/to/my/file.csv' })
  process.steps << ImportUsersStep.new
```

Notice that we didn't had to specify how the step would calculate the total count for the `ImportUsersStep`. It is already set to the number of lines in the CSV file of the `Massive::FileProcess`. For this we want to make sure that we have gathered information about the file:

```ruby
  process.file.gather_info!
```

We also didn't have to specify how the job would iterate through each row, it is already defined. We just get a CSV::Row, which will be a Hash-like structure where the header of the CSV is the key, so we can just pass it to `User.create`. Of course this is a simple example, you should protect the attributes, or even pass only the ones you want from the CSV.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

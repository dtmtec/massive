class CustomStep < Massive::Step
  calculates_total_count_with { 100 }
  job_class 'CustomJob'

  limit_ratio 3000 => 1500, 2000 => 1000, 0 => 100

  protected

  def job_params(index)
    {
      offset: index * limit,
      limit: limit,
      custom_param: "some_param"
    }
  end
end

class InheritedStep < Massive::Step
end

class CustomStepWithNilTotalCount < Massive::Step
  calculates_total_count_with { nil }
end

module Massive
  class FileProcess < Massive::Process
    embeds_one :file,  class_name: 'Massive::File', autobuild: true

    accepts_nested_attributes_for :file
  end
end

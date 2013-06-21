class Author < ActiveRecord::Base
  # The arXiv has no concept of uniqueness for authors
  # with the same name; our uniqid is a bit of a fake
  # placeholder generated by hashing the other attributes
  attr_accessible :uniqid

  # searchterm like Toner_B used for lookup as per arXiv search
  attr_accessible :searchterm

  # String data that we receive directly from arxivsync
  attr_accessible :affiliation, :forenames, :keyname, :suffix

  has_many :authorships
  has_many :papers, through: :authorships

  def self.make_uniqid(model)
    Digest::SHA1.hexdigest(model.forenames.inspect+model.keyname.inspect+model.suffix.inspect+model.affiliation.inspect)
  end

  def self.arxiv_import(models, opts={})
    uniqids = models.map { |model| Author.make_uniqid(model) }
    existing_uniqids = Author.find_all_by_uniqid(uniqids).map(&:uniqid)

    columns = [:uniqid, :affiliation, :forenames, :keyname, :suffix, :searchterm]
    values = []

    models.each_with_index do |model, i|
      uniqid = uniqids[i]
      next if existing_uniqids.include?(uniqid)
      values << [
        uniqid,
        model.affiliation,
        model.forenames,
        model.keyname,
        model.suffix,
        Author.make_searchterm(model)
      ]
    end

    result = Author.import(columns, values, opts)
    unless result.failed_instances.empty?
      Scirate3.notify_error("Error importing authors: #{result.failed_instances.inspect}")
    end

    puts "Read #{models.length} authors: #{values.length} new [#{models[0].keyname} to #{models[-1].keyname}]"
  end

  def self.make_searchterm(model)
    term = "#{model.keyname.tr('-','_').mb_chars.normalize(:kd).gsub(/[^\x00-\x7f]/n, '').to_s}"
    term += "_#{model.forenames[0][0]}" if model.forenames
  end

  def name
    name = keyname
    name = forenames + ' ' + name if forenames
    name = name + ' ' + suffix if suffix
  end
end

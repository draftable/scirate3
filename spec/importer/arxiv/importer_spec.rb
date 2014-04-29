require 'spec_helper'
require 'arxivsync'

describe "arxiv importer" do
  before(:all) do
    archive = ArxivSync::XMLArchive.new("#{Rails.root.to_s}/spec/data/arxiv")
    archive.read_metadata do |models|
      @models = models
    end
  end

  describe 'when importing papers failed' do
    it 'notifies the errors' do
      allow(Paper).to receive(:import).and_return(double(failed_instances: ['failed']))
      allow(Search::Paper).to receive(:index_by_uids) # stub out indexer
      expect(SciRate3).to receive(:notify_error).once

      Arxiv::Import.papers(@models)
    end
  end

  describe 'when importing versions failed' do
    it 'notifies the errors' do
      allow(Version).to receive(:import).and_return(double(failed_instances: ['failed']))
      expect(SciRate3).to receive(:notify_error).once

      Arxiv::Import.papers(@models)
    end
  end

  describe 'when importing authors failed' do
    it 'notifies the errors' do
      allow(Author).to receive(:import).and_return(double(failed_instances: ['failed']))
      expect(SciRate3).to receive(:notify_error).once

      Arxiv::Import.papers(@models)
    end
  end

  describe 'when importing categories failed' do
    it 'notifies the errors' do
      allow(Category).to receive(:import).and_return(double(failed_instances: ['failed']))
      expect(SciRate3).to receive(:notify_error).once

      Arxiv::Import.papers(@models)
    end
  end

  it "updates existing papers correctly" do
    Arxiv::Import.papers(@models)

    paper = Paper.find_by_uid("0811.3648")
    user = FactoryGirl.create(:user)
    FactoryGirl.create(:comment, paper: paper, user: user)
    user.scite!(paper)
    paper.reload

    paper.scites_count.should == 1
    paper.comments_count.should == 1
    paper.update_date = paper.update_date - 1.days
    paper.save!

    Arxiv::Import.papers(@models)

    paper = Paper.find_by_uid("0811.3648")
    paper.scites_count.should == 1
    paper.comments_count.should == 1
  end

  it "imports papers into the database" do
    Search.drop
    Search.migrate

    puts "Starting test"
    paper_uids = Arxiv::Import.papers(@models)

    paper_uids.length.should == 1000

    paper = Paper.find_by_uid(paper_uids[0])

    # Primary imports
    paper.uid.should == "0811.3648"
    paper.submitter.should == "Jelani Nelson"
    paper.versions[0].date.should == Time.parse("Fri, 21 Nov 2008 22:55:07 GMT")
    paper.versions[0].size.should == "90kb"
    paper.versions[1].date.should == Time.parse("Thu, 9 Apr 2009 02:45:30 GMT")
    paper.versions[1].size.should == "71kb"
    paper.title.should == "Revisiting Norm Estimation in Data Streams"
    paper.author_str.should == "Daniel M. Kane, Jelani Nelson, David P. Woodruff"
    paper.authors.map(&:fullname).should == ["Daniel M. Kane", "Jelani Nelson", "David P. Woodruff"]
    paper.feeds.map(&:uid).should == ["cs.DS", "cs.CC"]
    paper.author_comments.should == "added content; modified L_0 algorithm -- ParityLogEstimator in version 1 contained an error, and the new algorithm uses slightly more space"
    paper.license.should == "http://arxiv.org/licenses/nonexclusive-distrib/1.0/"
    paper.abstract.should include "The problem of estimating the pth moment F_p"

    # Calculated from above
    paper.submit_date.should == Time.parse("Fri, 21 Nov 2008 22:55:07 UTC")
    paper.update_date.should == Time.parse("Thu, 9 Apr 2009 02:45:30 UTC")
    paper.pubdate.should == Time.parse("Tue, 25 Nov 2008 01:00 UTC")
    paper.abs_url.should == "http://arxiv.org/abs/0811.3648"
    paper.pdf_url.should == "http://arxiv.org/pdf/0811.3648.pdf"

    # Ensure last_paper_date is updated on all feeds including parents
    paper.feeds.each do |feed|
      feed.last_paper_date.should_not be_nil
      feed.parent.last_paper_date.should_not be_nil
    end

    # Now test the search index
    Search.refresh
    Search::Paper.es_basic("*").raw.hits.total.should == 1000

    doc = Search::Paper.es_basic("title:\"Revisiting Norm Estimation in Data Streams\"").docs[0]
    doc._id.should == "0811.3648"
    doc.title.should == "Revisiting Norm Estimation in Data Streams"
    doc.authors_fullname.should == ["Daniel M. Kane", "Jelani Nelson", "David P. Woodruff"]
    doc.authors_searchterm.should == ["Kane_D", "Nelson_J", "Woodruff_D"]
    doc.feed_uids.should == ["cs.DS", "cs.CC"]
    doc.abstract.should include "The problem of estimating the pth moment F_p"
    Time.parse(doc.submit_date).should == Time.parse("Fri, 21 Nov 2008 22:55:07 UTC")
    Time.parse(doc.update_date).should == Time.parse("Thu, 9 Apr 2009 02:45:30 UTC")
    Time.parse(doc.pubdate).should == Time.parse("Tue, 25 Nov 2008 01:00 UTC")

    # And the bulk indexer
    Search.drop
    Search.migrate
    Search.refresh

    Search::Paper.es_basic("*").raw.hits.total.should == 1000

    doc = Search::Paper.es_basic("title:\"Revisiting Norm Estimation in Data Streams\"").docs[0]
    doc._id.should == "0811.3648"
    doc.title.should == "Revisiting Norm Estimation in Data Streams"
    doc.authors_fullname.should == ["Daniel M. Kane", "Jelani Nelson", "David P. Woodruff"]
    doc.authors_searchterm.should == ["Kane_D", "Nelson_J", "Woodruff_D"]
    doc.feed_uids.should == ["cs.DS", "cs.CC"]
    doc.abstract.should include "The problem of estimating the pth moment F_p"
    Time.parse(doc.submit_date).should == Time.parse("Fri, 21 Nov 2008 22:55:07 UTC")
    Time.parse(doc.update_date).should == Time.parse("Thu, 9 Apr 2009 02:45:30 UTC")
    Time.parse(doc.pubdate).should == Time.parse("Tue, 25 Nov 2008 01:00 UTC")
  end
end

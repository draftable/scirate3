# == Schema Information
#
# Table name: papers
#
#  id              :integer          not null, primary key
#  uid             :text             not null
#  submitter       :text
#  title           :text             not null
#  abstract        :text             not null
#  author_comments :text
#  msc_class       :text
#  report_no       :text
#  journal_ref     :text
#  doi             :text
#  proxy           :text
#  license         :text
#  submit_date     :datetime         not null
#  update_date     :datetime         not null
#  abs_url         :text             not null
#  pdf_url         :text             not null
#  created_at      :datetime
#  updated_at      :datetime
#  scites_count    :integer          default(0), not null
#  comments_count  :integer          default(0), not null
#  pubdate         :datetime
#  author_str      :text             not null
#

class Paper < ActiveRecord::Base
  has_many  :versions, -> { order("position ASC") }, dependent: :delete_all,
            foreign_key: :paper_uid, primary_key: :uid
  has_many  :categories, -> { order("categories.position ASC") }, dependent: :delete_all,
            foreign_key: :paper_uid, primary_key: :uid
  has_many  :authors, -> { order("position ASC") }, dependent: :delete_all,
            foreign_key: :paper_uid, primary_key: :uid

  has_many  :feeds, through: :categories

  has_many  :scites, dependent: :delete_all,
            foreign_key: :paper_uid, primary_key: :uid
  has_many  :sciters, -> { order("fullname ASC") }, through: :scites, source: :user
  has_many  :comments, -> { order("created_at ASC") }, dependent: :delete_all,
            foreign_key: :paper_uid, primary_key: :uid

  validates :uid, presence: true, uniqueness: true
  validates :title, presence: true
  validates :abstract, presence: true
  validates :abs_url, presence: true
  validates :submit_date, presence: true
  validates :update_date, presence: true

  validate :update_date_is_after_submit_date

  after_save do
    ::Search::Paper.index(self)
  end

  def refresh_comments_count!
    self.comments_count = Comment.where(
      paper_uid: uid,
      deleted: false,
      hidden: false
    ).count

    save!
  end

  def refresh_scites_count!
    self.scites_count = Scite.where(paper_uid: uid).count
    save!
  end

  def to_param
    uid
  end

  def updated?
    update_date > submit_date
  end

  private

    def update_date_is_after_submit_date
      return unless submit_date and update_date

      if update_date < submit_date
        errors.add(:update_date, "must not be earlier than submit_date")
      end
    end

end

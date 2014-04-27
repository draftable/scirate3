class PapersController < ApplicationController
  include PapersHelper

  def show
    @paper = Paper.find_by_uid!(paper_id)
    @scited = current_user && current_user.scited_papers.where(id: @paper.id).exists?
    @comments = find_comments_sorted_by_rating
  end

  def __quote(val)
    val.include?(' ') ? "(#{val})" : val
  end

  def search
    basic = params[:q]
    advanced = params[:advanced]
    page = params[:page] ? params[:page].to_i : 1

    @search = Search::Paper::Query.new(basic, advanced)

    per_page = 70

    if !@search.query.empty?
      paper_uids = @search.run(from: (page-1)*per_page, size: per_page).documents.map(&:_id)

      @papers = Paper.includes(:authors, :feeds)
                     .where(uid: paper_uids)
                     .index_by(&:uid)
                     .slice(*paper_uids)
                     .values

      @pagination = WillPaginate::Collection.new(page, per_page, @search.results.raw.hits.total)

      # Determine which folder we should have selected
      @folder_uid = @search.feed && (@search.feed.parent_uid || @search.feed.uid)

      @scited_ids = current_user.scited_papers.pluck(:id) if current_user
    end

    render :search
  end

  # Show the users who scited this paper
  def scites
    @paper = Paper.find_by_uid!(params[:id])
  end

  def next
    date = parse_date params
    feed = parse_feed params

    if feed.nil? && signed_in? && current_user.has_subscriptions?
       date ||= current_user.feed_last_paper_date

      papers = current_user.feed
    else
      feed ||= Feed.default
      date ||= feed.last_paper_date

      papers = feed.cross_listed_papers
    end

    ndate = next_date(papers, date)

    if ndate.nil?
      flash[:error] = "No future papers found!"
      ndate = date
    end

    redirect_to papers_path(params.merge(date: ndate, action: nil))
  end

  def prev
    date = parse_date params
    feed = parse_feed params

    if feed.nil? && signed_in? && current_user.has_subscriptions?
      date ||= current_user.feed_last_paper_date
      papers = current_user.feed
    else
      feed ||= Feed.default
      date ||= feed.last_paper_date

      papers = feed.cross_listed_papers
    end

    pdate = prev_date(papers, date)

    if pdate.nil?
      flash[:error] = "No past papers found!"
      pdate = date
    end

    redirect_to papers_path(params.merge(date: pdate, action: nil))
  end

  private

  def paper_id
    if has_versioning_suffix?(params[:id])
      params[:id].split(/v\d/)[0]
    else
      params[:id]
    end
  end

  def has_versioning_suffix?(id)
    id =~ /v\d/
  end

  # Less naive statistical comment sorting as per
  # http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
  def find_top_level_comments
    total_votes = %Q{ NULLIF(cached_votes_up + cached_votes_down, 0) }
    Comment.find_by_sql([
      %Q{
        SELECT *, COALESCE(
          ((cached_votes_up + 1.9208) / #{total_votes} - 1.96 * SQRT((cached_votes_up * cached_votes_down) / #{total_votes} + 0.9604) / #{total_votes} ) / (1 + 3.8416 / #{total_votes})
        , 0) AS ci_lower_bound
        FROM comments
        WHERE paper_uid = ? AND ancestor_id IS NULL AND deleted = FALSE
        AND (hidden = FALSE OR user_id = ?)
        ORDER BY ci_lower_bound DESC, created_at ASC;
      }, @paper.uid, current_user.try(:id)])
  end

  def find_comments_with_ancestors(ancestors)
    ancestor_ids = ancestors.map(&:id)
    @paper.comments.where(ancestor_id: ancestor_ids, deleted: false).order('created_at ASC')
  end

  def find_comments_sorted_by_rating
    toplevel_comments = find_top_level_comments
    comment_tree = find_comments_with_ancestors(toplevel_comments).group_by(&:ancestor_id)

    comments = []
    toplevel_comments.each do |ancestor|
      comments << ancestor
      comments += comment_tree[ancestor.id] || []
    end

    comments
  end
end

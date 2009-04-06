class Ubiquo::AssetsController < UbiquoAreaController
  ubiquo_config_call :assets_access_control, {:context => :ubiquo_media}
  before_filter :load_asset_visibilities
  before_filter :load_tags
  before_filter :load_asset_types

  # GET /assets
  # GET /assets.xml
  def index
    params[:order_by] = params[:order_by] || Ubiquo::Config.context(:ubiquo_media).get(:assets_default_order_field)
    params[:sort_order] = params[:sort_order] || Ubiquo::Config.context(:ubiquo_media).get(:assets_default_sort_order)
    filters = {
      :tag => params[:filter_tag], 
      :type => params[:filter_type], 
      :text => params[:filter_text],
      :visibility => params[:filter_visibility],
      :created_start => parse_date(params[:filter_created_start]),
      :created_end => parse_date(params[:filter_created_end], :time_offset => 1.day),         
    }
    per_page = Ubiquo::Config.context(:ubiquo_media).get(:assets_elements_per_page)
    @assets_pages, @assets = Asset.paginate(:page => params[:page], :per_page => per_page) do
      Asset.filtered_search(filters, :order => params[:order_by] + " " + params[:sort_order])
    end
    
    respond_to do |format|
      format.html{ } # index.html.erb
      format.xml{
        render :xml => @assets
      }
    end
  end

  # GET /assets/new
  # GET /assets/new.xml
  def new
    @asset = AssetPublic.new

    respond_to do |format|
      format.html{ } # new.html.erb
      format.xml{ render :xml => @asset }
    end
  end

  # GET /assets/1/edit
  def edit
    @asset = Asset.find(params[:id])
  end

  # POST /assets
  # POST /assets.xml
  def create
    field = params.delete(:field)
    visibility = get_visibility(params)
    asset_visibility = "asset_#{visibility}".classify.constantize
    @asset = asset_visibility.new(params[:asset])
    respond_to do |format|
      if @asset.save
        flash[:notice] = t('ubiquo.media.asset_created')
        format.html { redirect_to(ubiquo_assets_path) }
        format.xml  { render :xml => @asset, :status => :created, :location => @asset }
        format.js {
          responds_to_parent do 
            render :update do |page|
              created = @asset
              @asset = asset_visibility.new(params[:asset])
              page.replace_html "add_#{field}", :partial => "ubiquo/asset_relations/asset_form",
                                                            :locals => { :field => field, 
                                                                         :visibility => visibility }
              page.hide "add_#{field}"
              page << "media_fields.add_element('#{field}', #{created.id}, #{created.name.to_json}, #{thumbnail_url(created).to_json}, #{view_asset_link(created).to_json});"
            end
          end
        }
      else
        flash[:error] = t('ubiquo.media.asset_create_error')
        format.html {
          render :action => "new"
        }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
        format.js {
          responds_to_parent do 
            render :update do |page|
              page.replace_html "add_#{field}", :partial => "ubiquo/asset_relations/asset_form", :locals => {:field => field, :visibility => visibility }
            end
          end
        }
      end
    end
  end

  # PUT /assets/1
  # PUT /assets/1.xml
  def update
    @asset = Asset.find(params[:id])
    require 'ruby-debug';debugger
    visibility = get_visibility(params)
    respond_to do |format|
      if @asset.update_attributes(params[:asset])
        flash[:notice] = t('ubiquo.media.asset_updated')
        format.html { redirect_to(ubiquo_assets_path) }
        format.xml  { head :ok }
      else
        flash[:error] = t('ubiquo.media.asset_update_error')
        format.html {
          render :action => "edit"
        }
        format.xml  { render :xml => @asset.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /assets/1
  # DELETE /assets/1.xml
  def destroy
    @asset = Asset.find(params[:id])
    if @asset.destroy
      flash[:notice] = t('ubiquo.media.asset_removed')
    else
      flash[:error] = t('ubiquo.media.asset_remove_error')
    end

    respond_to do |format|
      format.html { redirect_to(ubiquo_assets_path) }
      format.xml  { head :ok }
    end
  end
  
  # GET /assets  
  def search
    @field = params[:field] 
    @search_text = params[:text]
    @page = params[:page] || 1
    @assets_pages, @assets = Asset.paginate(:page => @page, :per_page => Ubiquo::Config.context(:ubiquo_media).get(:media_selector_list_size)) do
      Asset.filtered_search({:text => @search_text, :type => params[:asset_type_id], :visibility => params[:visibility]})
    end
  end
  
  private
  
  def load_asset_visibilities
    @asset_visibilities = [
                           OpenStruct.new(:key => 'public', :name => t('ubiquo.media.public')),
                           OpenStruct.new(:key => 'private', :name => t('ubiquo.media.private'))
                          ]
  end

  def load_tags
    @tags = Tag.find_for_assets
  end
  
  def load_asset_types
    @asset_types = AssetType.find :all
  end
  
  def get_visibility(params)
    if params[:asset][:is_protected] == "private" || params[:asset][:is_protected] == "1"
      "private"
    else
      "public"
    end
  end

end

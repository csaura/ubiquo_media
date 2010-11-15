module Ubiquo::AssetsHelper

  def asset_filters
    string_filter_enabled = Ubiquo::Config.context(:ubiquo_media).get(:assets_string_filter_enabled)
    type_filter_enabled = Ubiquo::Config.context(:ubiquo_media).get(:assets_asset_types_filter_enabled)
    visibility_filter_enabled = (Ubiquo::Config.context(:ubiquo_media).get(:assets_asset_visibility_filter_enabled) && !Ubiquo::Config.context(:ubiquo_media).get(:force_visibility))
    date_filter_enabled = Ubiquo::Config.context(:ubiquo_media).get(:assets_date_filter_enabled)

    asset_types =  @asset_types.map{|lk| OpenStruct.new(:key => lk.id, :name => I18n.t("ubiquo.asset_type.names.#{lk.key}"))}

    filters_for 'Asset' do |f|
      f.text(:caption => t('ubiquo.media.text')) if string_filter_enabled
      f.link(:type, asset_types, {
        :id_field => :key,
        :caption => t('ubiquo.media.type'),
        :all_caption => t('ubiquo.media.all')
      }) if type_filter_enabled
      f.link(:visibility, @asset_visibilities, {
        :caption => t('ubiquo.media.visibility'),
        :id_field => :key
      }) if visibility_filter_enabled
      f.date({
        :field => [:filter_created_start, :filter_created_end],
        :caption => t('ubiquo.media.creation')
      }) if date_filter_enabled
      # uhook_asset_filters f
    end
  end

end

require File.dirname(__FILE__) + "/../../test_helper"

class UbiquoMedia::Connectors::I18nTest < ActiveSupport::TestCase

  I18n = UbiquoMedia::Connectors::I18n

  if Ubiquo::Plugin.registered[:ubiquo_i18n]

    def setup
      save_current_connector(:ubiquo_media)
      I18n.load!
      define_translatable_test_model
    end

    def teardown
      reload_old_connector(:ubiquo_media)
    end

    test 'uhook_create_asset_relations_table_should_create_table' do
      ActiveRecord::Migration.expects(:create_table).with(:asset_relations, :translatable => true)
      ActiveRecord::Migration.uhook_create_asset_relations_table {}
    end

    test 'uhook_default_values_in_asset_relations_should_the_locale_if_related_object_is_translatable' do
      object = UbiquoMedia::TestModel.new :locale => 'jp'
      assert_equal({:locale => 'jp'}, AssetRelation.uhook_default_values(object, nil))
    end

    test 'uhook_default_values_in_asset_relations_should_empty_hash_if_related_object_is_not_translatable' do
      assert_equal({}, AssetRelation.uhook_default_values(Asset.new, nil))
    end

    test 'uhook_filtered_search_in_asset_relations_should_yield_with_locale_filter' do
      AssetRelation.expects(:all)
      AssetRelation.expects(:with_scope).with(:find => {:conditions => ["asset_relations.locale <= ?", 'ca']}).yields
      AssetRelation.uhook_filtered_search({:locale => 'ca'}) { AssetRelation.all }
    end

    test 'uhook_media_attachment should add translation_shared option if set' do
      Asset.class_eval do
        media_attachment :simple
      end
      Asset.uhook_media_attachment :simple, {:translation_shared => true}
      assert Asset.reflections[:simple].options[:translation_shared]
    end

    test 'uhook_media_attachment should not add translation_shared option if not set' do
      Asset.class_eval do
        media_attachment :simple
      end
      Asset.uhook_media_attachment :simple, {:translation_shared => false}
      assert !Asset.reflections[:simple].options[:translation_shared]
    end

    test 'should not share attachments between translations if not defined' do
      UbiquoMedia::TestModel.class_eval do
        unshare_translations_for :photo
        media_attachment :photo, :translation_shared => false
      end

      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      translated_instance = instance.translate('en')
      translated_instance.save

      instance.photo << AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'photo')
      assert_equal 0, translated_instance.reload.photo.size
    end

    test 'should share attachments between translations when defined' do
      UbiquoMedia::TestModel.class_eval do
        media_attachment :photo, :translation_shared => true
      end

      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      translated_instance = instance.translate('en')
      translated_instance.save

      instance.photo << AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'photo')
      assert_equal 1, translated_instance.reload.photo.size
    end

    test 'should not share attachments for the main :asset_relations reflection' do
      UbiquoMedia::TestModel.class_eval do
        media_attachment :photo, :translation_shared => true
      end

      assert !UbiquoMedia::TestModel.reflections[:asset_relations].is_translation_shared?
    end

    test 'should ony display the specific media attachment and not all of them' do
      UbiquoMedia::TestModel.class_eval do
        media_attachment :photo, :translation_shared => true
        media_attachment :video, :translation_shared => true
      end

      Locale.current = 'ca'
      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      instance.photo << photo = AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'photo')
      instance.save

      assert_equal photo, instance.photo.first
      assert_equal photo, instance.reload.photo.first

      # this fails cause instance.video == instance.photo
      assert instance.video.blank?
      assert instance.reload.video.blank?
      assert instance.reload.video.reload.blank?
      assert instance.video.blank?
    end

    test 'should not duplicate asset relations with different content_id when assigning directly' do
      UbiquoMedia::TestModel.class_eval do
        media_attachment :gallery, :translation_shared => true
      end

      Locale.current = 'ca'
      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      2.times do
        instance.gallery << AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'gallery')
      end

      instance.save
      Locale.current = 'en'
      translation = instance.translate('en')
      translation.gallery # load the association, required to recreate the bug
      translation.save
      assert_equal 2, translation.reload.gallery.size
    end

    test 'should share attachments between translations when assignating' do
      UbiquoMedia::TestModel.class_eval do
        media_attachment :photo, :translation_shared => true
      end

      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      translated_instance = instance.translate('en')
      translated_instance.save

      instance.photo = [AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'photo')]
      assert_equal 1, translated_instance.reload.photo.size
    end

    test 'should only update asset relation name in one translation' do
      UbiquoMedia::TestModel.class_eval do
        media_attachment :photo, :translation_shared => true
      end

      Locale.current = 'ca'
      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      translated_instance = instance.translate('en')
      translated_instance.save
      instance.photo << photo = AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'photo')

      # save the original name in the translation and then update it
      original_name = AssetRelation.name_for_asset :photo, translated_instance.reload.photo.first, translated_instance

      Locale.current = 'en'
      translated_instance.photo_attributes = [{
        "id" => translated_instance.photo_asset_relations.first.id.to_s,
        "asset_id" => photo.id.to_s,
        "name" => 'newname'
      }]
      translated_instance.save

      # name successfully changed
      assert_equal 'newname', translated_instance.name_for_asset(:photo, photo)
      # translation untouched
      assert_equal original_name, instance.name_for_asset(:photo, photo)
    end

    test 'should create a translated asset relation when the object is really new' do
      # it might happen in a controller that asset relations are assigned before
      # the content_id, so this situation must be under control
      UbiquoMedia::TestModel.class_eval do
        media_attachment :photo, :translation_shared => true
      end

      Locale.current = 'ca'
      instance = UbiquoMedia::TestModel.create :locale => 'ca'
      instance.photo << photo = AssetPublic.create(:resource => Tempfile.new('tmp'), :name => 'photo')
      translated_instance = instance.translate('en')
      translated_instance.content_id = nil

      # save the original name in the translation and then update it
      original_name = AssetRelation.name_for_asset :photo, photo, translated_instance

      Locale.current = 'en'
      translated_instance.photo_attributes = [{
        "id" => instance.photo_asset_relations.first.id.to_s,
        "asset_id" => photo.id.to_s,
        "name" => 'newname'
      }]
      translated_instance.content_id = instance.content_id
      translated_instance.save

      # name successfully changed
      assert_equal 'newname', translated_instance.name_for_asset(:photo, photo)
      # translation untouched
      assert_equal original_name, instance.name_for_asset(:photo, photo)
    end


    private

    def define_translatable_test_model
      unless defined? UbiquoMedia::TestModel
        model = Class.new(ActiveRecord::Base)
        UbiquoMedia.const_set(:TestModel, model)
      end
      UbiquoMedia::TestModel.class_eval do
        set_table_name 'ubiquo_media_test_models'
      end
      unless UbiquoMedia::TestModel.table_exists?
        ActiveRecord::Base.connection.create_table(:ubiquo_media_test_models, :translatable => true) {}
      end
      UbiquoMedia::TestModel.translatable
    end

  else
    puts 'ubiquo_i18n not found, omitting UbiquoMedia::Connectors::I18n tests'
  end
end

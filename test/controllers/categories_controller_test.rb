require 'test_helper'

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Project.create!(
      url: 'https://github.com/test/project1',
      category: 'test-category',
      sub_category: 'test-subcategory',
      reviewed: true
    )
  end

  test 'renders 404 when category does not exist' do
    get '/categories/nonexistent-category'
    assert_response :not_found
  end

  test 'renders 404 when sub_category does not exist' do
    get '/categories/test-category/nonexistent-subcategory'
    assert_response :not_found
  end

  test 'shows category when it exists' do
    get '/categories'
    assert_response :success
  end

  test 'shows category and sub_category when both exist' do
    get '/categories/test-category/test-subcategory'
    assert_response :success
  end
end

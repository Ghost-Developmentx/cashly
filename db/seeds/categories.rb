# db/seeds/categories.rb

# Main categories
income = Category.find_or_create_by(name: 'income') do |category|
  category.description = 'Money received'
end

housing = Category.find_or_create_by(name: 'housing') do |category|
  category.description = 'Housing and accommodation expenses'
end

transportation = Category.find_or_create_by(name: 'transportation') do |category|
  category.description = 'Car, public transit, and other transportation costs'
end

food = Category.find_or_create_by(name: 'food') do |category|
  category.description = 'Groceries and dining out'
end

utilities = Category.find_or_create_by(name: 'utilities') do |category|
  category.description = 'Electric, water, gas, internet, phone bills'
end

healthcare = Category.find_or_create_by(name: 'healthcare') do |category|
  category.description = 'Medical expenses, insurance, prescriptions'
end

personal = Category.find_or_create_by(name: 'personal') do |category|
  category.description = 'Personal care, clothing, and entertainment'
end

education = Category.find_or_create_by(name: 'education') do |category|
  category.description = 'Education and professional development'
end

savings = Category.find_or_create_by(name: 'savings') do |category|
  category.description = 'Savings and investments'
end

debt = Category.find_or_create_by(name: 'debt') do |category|
  category.description = 'Debt payments other than housing'
end

business = Category.find_or_create_by(name: 'business') do |category|
  category.description = 'Business expenses'
end

other = Category.find_or_create_by(name: 'other') do |category|
  category.description = 'Uncategorized expenses'
end

# Sub-categories

# Income
Category.find_or_create_by(name: 'salary', parent_category: income) do |category|
  category.description = 'Regular salary or wages'
end

Category.find_or_create_by(name: 'freelance', parent_category: income) do |category|
  category.description = 'Freelance or contract work income'
end

Category.find_or_create_by(name: 'investment', parent_category: income) do |category|
  category.description = 'Income from investments'
end

# Housing
Category.find_or_create_by(name: 'rent', parent_category: housing) do |category|
  category.description = 'Rent payments'
end

Category.find_or_create_by(name: 'mortgage', parent_category: housing) do |category|
  category.description = 'Mortgage payments'
end

Category.find_or_create_by(name: 'property_tax', parent_category: housing) do |category|
  category.description = 'Property taxes'
end

Category.find_or_create_by(name: 'repairs', parent_category: housing) do |category|
  category.description = 'Home repairs and maintenance'
end

# Transportation
Category.find_or_create_by(name: 'car_payment', parent_category: transportation) do |category|
  category.description = 'Car loan or lease payments'
end

Category.find_or_create_by(name: 'gas', parent_category: transportation) do |category|
  category.description = 'Gasoline and fuel'
end

Category.find_or_create_by(name: 'public_transit', parent_category: transportation) do |category|
  category.description = 'Public transportation'
end

Category.find_or_create_by(name: 'car_insurance', parent_category: transportation) do |category|
  category.description = 'Car insurance'
end

Category.find_or_create_by(name: 'car_maintenance', parent_category: transportation) do |category|
  category.description = 'Car maintenance and repairs'
end

# Food
Category.find_or_create_by(name: 'groceries', parent_category: food) do |category|
  category.description = 'Grocery shopping'
end

Category.find_or_create_by(name: 'restaurants', parent_category: food) do |category|
  category.description = 'Dining out, takeout, delivery'
end

Category.find_or_create_by(name: 'coffee_shops', parent_category: food) do |category|
  category.description = 'Coffee shops, cafes'
end

# Utilities
Category.find_or_create_by(name: 'electricity', parent_category: utilities) do |category|
  category.description = 'Electricity bills'
end

Category.find_or_create_by(name: 'water', parent_category: utilities) do |category|
  category.description = 'Water bills'
end

Category.find_or_create_by(name: 'internet', parent_category: utilities) do |category|
  category.description = 'Internet service'
end

Category.find_or_create_by(name: 'phone', parent_category: utilities) do |category|
  category.description = 'Mobile and landline phone bills'
end

puts "Default categories created!"

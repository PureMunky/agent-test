# Expenses

A command-line personal expense tracker and budget manager. Track spending by category, set monthly budgets, and generate reports to understand your financial habits.

## Features

- **Expense Tracking**: Log expenses with amounts, categories, and descriptions
- **Income Tracking**: Track income sources separately
- **Budget Management**: Set monthly budgets per category with warnings
- **Visual Progress**: Budget progress bars and spending summaries
- **Search & Filter**: Find expenses by date range, category, or text
- **Reports**: Generate detailed spending reports
- **Export**: Export data to CSV or JSON
- **Tags**: Support for inline #tags in descriptions

## Requirements

- `jq` - JSON processor (`sudo apt install jq`)
- `bc` - Basic calculator (usually pre-installed)

## Usage

### Adding Expenses

```bash
# Add an expense
./expenses.sh add 12.50 food "Lunch at cafe"

# Add with tags
./expenses.sh add 45.00 shopping "New headphones #electronics #work"

# Quick add (shortest form)
./expenses.sh a 9.99 entertainment
```

### Adding Income

```bash
./expenses.sh income 3000 "Monthly salary"
./expenses.sh income 500 "Freelance project"
```

### Viewing Expenses

```bash
# List this month's expenses (default)
./expenses.sh list

# List today's expenses
./expenses.sh list --today

# List this week's expenses
./expenses.sh list --week

# List this year's expenses
./expenses.sh list --year

# List all expenses
./expenses.sh list --all
```

### Spending Summary

```bash
# This month's summary (default)
./expenses.sh summary

# Weekly summary
./expenses.sh summary --week

# Yearly summary
./expenses.sh summary --year
```

### Budget Management

```bash
# Set a monthly budget for a category
./expenses.sh budget food 500
./expenses.sh budget entertainment 100

# View all budgets with progress
./expenses.sh budgets

# Remove a budget
./expenses.sh budget food 0
```

### Categories

```bash
# List categories with spending totals
./expenses.sh categories
```

Default categories: food, transport, shopping, entertainment, utilities, health, education, other

You can use any custom category name.

### Search

```bash
# Search in descriptions and categories
./expenses.sh search "coffee"
./expenses.sh search "#work"
```

### Editing and Deleting

```bash
# Edit an expense
./expenses.sh edit 5 amount 15.00
./expenses.sh edit 5 category food
./expenses.sh edit 5 description "Updated description"
./expenses.sh edit 5 date 2026-01-15

# Delete an expense
./expenses.sh delete 5
```

### Reports

```bash
# Monthly report
./expenses.sh report

# Yearly report
./expenses.sh report --year
```

Reports include:
- Income vs expenses summary
- Spending by category with percentages
- Top 5 largest expenses
- Budget status for all tracked budgets

### Export

```bash
# Export to CSV
./expenses.sh export --csv

# Export to JSON
./expenses.sh export --json
```

### Configuration

```bash
# Change currency symbol
./expenses.sh currency €
./expenses.sh currency £
```

## Examples

### Track Daily Expenses

```bash
./expenses.sh add 4.50 food "Morning coffee"
./expenses.sh add 12.00 food "Lunch"
./expenses.sh add 35.00 transport "Gas"
./expenses.sh list --today
```

### Monthly Budget Workflow

```bash
# Set budgets at start of month
./expenses.sh budget food 600
./expenses.sh budget entertainment 150
./expenses.sh budget transport 200

# Check progress throughout month
./expenses.sh budgets

# End of month review
./expenses.sh report
```

### Track Project Expenses

```bash
./expenses.sh add 199.00 software "IDE license #projectA"
./expenses.sh add 29.99 books "Programming book #projectA"
./expenses.sh search "#projectA"
```

## File Storage

- Expenses are stored in `data/expenses.json`
- Budgets are stored in `data/budgets.json`
- Configuration in `data/config.json`

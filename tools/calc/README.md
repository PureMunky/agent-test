# Calc

A quick command-line calculator and unit converter for everyday calculations.

## Features

- **Math Expressions**: Evaluate arithmetic with support for common functions
- **Unit Conversion**: Convert between length, weight, data, time, volume, and temperature
- **Date Calculations**: Days between dates, add/subtract time
- **Practical Tools**: Tip calculator, bill splitter, percentage calculations
- **History**: Track recent calculations

## Requirements

- `bc` - Calculator (usually pre-installed on Linux/macOS)
- Bash 4.0+

## Usage

### Basic Math

```bash
# Simple arithmetic
./calc.sh 2 + 2
./calc.sh '100 / 7'
./calc.sh '(5 * 3) + 10'

# Powers and roots
./calc.sh '2^10'
./calc.sh 'sqrt(144)'

# Percentage shorthand
./calc.sh '20% of 150'
```

### Unit Conversion

```bash
# Length
./calc.sh conv 100 km miles
./calc.sh conv 6 feet meters
./calc.sh conv 5.5 inches cm

# Weight
./calc.sh conv 150 lbs kg
./calc.sh conv 2.5 kg pounds

# Temperature
./calc.sh conv 72 f c
./calc.sh conv 100 c f
./calc.sh conv 0 c k

# Data sizes
./calc.sh conv 1024 mb gb
./calc.sh conv 2 tb gb

# Time
./calc.sh conv 180 min hours
./calc.sh conv 3 days hours

# Volume
./calc.sh conv 2 gallons liters
./calc.sh conv 500 ml cups
```

### Date Calculations

```bash
# Days between dates
./calc.sh date diff 2024-01-01              # Days since date
./calc.sh date diff 2024-01-01 2024-12-31   # Days between two dates

# Add time
./calc.sh date add 30 days                  # 30 days from now
./calc.sh date add 2 weeks 2024-06-01       # 2 weeks from a specific date
./calc.sh date add 3 months

# Subtract time
./calc.sh date sub 90 days
./calc.sh date sub 1 year 2025-01-01

# Week number
./calc.sh date week
./calc.sh date week 2024-07-04

# Current date/time
./calc.sh date now
```

### Practical Calculations

```bash
# Tip calculator (default 20%)
./calc.sh tip 45.50
./calc.sh tip 85 15       # 15% tip

# Split bill with tip
./calc.sh split 120 4     # Split $120 between 4 people
./calc.sh split 85.50 3 18  # With 18% tip

# What percentage is X of Y?
./calc.sh percent 25 200  # 25 is what % of 200?
./calc.sh percent 15 60   # 15 is what % of 60?
```

### History

```bash
# View recent calculations
./calc.sh history
./calc.sh history 20      # Show last 20

# Clear history
./calc.sh clear
```

### Available Units

```bash
./calc.sh units
```

**Length:** m, km, cm, mm, mi (miles), yd (yards), ft (feet), in (inches)

**Weight:** kg, g, mg, lb/lbs (pounds), oz (ounces), st (stone)

**Data:** b (bytes), kb, mb, gb, tb, pb

**Time:** s/sec, min, h/hr (hours), d (days), w (weeks)

**Volume:** l/liter, ml, gal (gallon), qt (quart), pt (pint), cup, floz

**Temperature:** c (celsius), f (fahrenheit), k (kelvin)

## Examples

```bash
# Quick calculations during the day
./calc.sh '1200 * 0.85'        # 15% discount on $1200
./calc.sh conv 5 miles km      # How far is 5 miles?
./calc.sh conv 98.6 f c        # Body temperature in Celsius
./calc.sh date diff 2024-12-25 # Days until Christmas

# Working with data
./calc.sh conv 500 gb tb       # Storage conversion
./calc.sh '1000000000 / 1024 / 1024 / 1024'  # Bytes to GB manually

# Time management
./calc.sh conv 8 hours min     # Hours to minutes
./calc.sh date add 2 weeks     # Deadline in 2 weeks
```

## Data Storage

- History is stored in `data/history.csv`
- Limited to prevent unbounded growth

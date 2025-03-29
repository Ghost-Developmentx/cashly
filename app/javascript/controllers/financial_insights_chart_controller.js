import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static targets = ["incomeExpense", "categoryDistribution", "dayOfWeek"]
    static values = {
        trends: Object,
        anomalies: Object
    }

    connect() {
        console.log("Financial Insights Controller Connected");
        // Add debug logging to help diagnose data issues
        if (this.trendsValue) {
            console.log("Trends data available:", this.trendsValue);
        } else {
            console.warn("No trends data available");
        }
        this.renderCharts();
    }

    renderCharts() {
        this.renderIncomeExpenseChart();
        this.renderCategoryDistributionChart();
        this.renderDayOfWeekChart();
    }

    renderIncomeExpenseChart() {
        if (!this.hasIncomeExpenseTarget) {
            console.warn("Income expense target not found");
            return;
        }

        // More robust checking for data structure
        if (!this.trendsValue) {
            console.warn("No trends data provided");
            this.showNoDataMessage(this.incomeExpenseTarget);
            return;
        }

        const monthlyTrends = this.trendsValue.monthly_trends;
        if (!monthlyTrends || !Array.isArray(monthlyTrends) || monthlyTrends.length === 0) {
            console.warn("Monthly trends data is missing or invalid:", monthlyTrends);
            this.showNoDataMessage(this.incomeExpenseTarget);
            return;
        }

        // Convert a data format to a series for ApexCharts
        const months = [];
        const incomeData = [];
        const expensesData = [];
        const netData = [];

        monthlyTrends.forEach(month => {
            // Make sure 'month' is actually an object
            if (!month || typeof month !== 'object') {
                console.warn("Invalid month entry in trends data:", month);
                return;
            }

            months.push(month.month || 'Unknown');

            // Handle missing or non-numeric values
            const income = typeof month.income === 'number' ? month.income : 0;
            const expenses = typeof month.expenses === 'number' ? Math.abs(month.expenses) : 0;
            const net = typeof month.net === 'number' ? month.net : 0;

            incomeData.push(income);
            expensesData.push(expenses); // Convert to positive for chart
            netData.push(net);
        });

        // If we have no valid data after processing, show a message
        if (months.length === 0) {
            this.showNoDataMessage(this.incomeExpenseTarget);
            return;
        }

        const options = {
            series: [
                {
                    name: 'Income',
                    data: incomeData
                },
                {
                    name: 'Expenses',
                    data: expensesData
                },
                {
                    name: 'Net',
                    data: netData
                }
            ],
            chart: {
                type: 'bar',
                height: 350,
                stacked: false
            },
            plotOptions: {
                bar: {
                    horizontal: false,
                    columnWidth: '60%',
                },
            },
            colors: ['#10B981', '#EF4444', '#3B82F6'],
            dataLabels: {
                enabled: false
            },
            stroke: {
                width: [0, 0, 3]
            },
            xaxis: {
                categories: months,
            },
            yaxis: {
                title: {
                    text: 'Amount'
                },
                labels: {
                    formatter: function (value) {
                        return '$' + Math.abs(value);
                    }
                }
            },
            tooltip: {
                y: {
                    formatter: function (val) {
                        return '$' + Math.abs(val);
                    }
                }
            },
            legend: {
                position: 'top'
            }
        };

        try {
            this.incomeExpenseChart = new ApexCharts(this.incomeExpenseTarget, options);
            this.incomeExpenseChart.render();
            console.log("Income/Expense chart rendered successfully");
        } catch (error) {
            console.error("Error rendering Income/Expense chart:", error);
            this.showErrorMessage(this.incomeExpenseTarget);
        }
    }

    renderCategoryDistributionChart() {
        if (!this.hasCategoryDistributionTarget) {
            console.warn("Category distribution target not found");
            return;
        }

        // More thorough data validation
        if (!this.trendsValue || !this.trendsValue.category_breakdown ||
            typeof this.trendsValue.category_breakdown !== 'object') {
            console.warn("Category breakdown data is missing or invalid");
            this.showNoDataMessage(this.categoryDistributionTarget);
            return;
        }

        const categoryBreakdown = this.trendsValue.category_breakdown;

        // Convert data format to series for ApexCharts
        const categories = [];
        const values = [];

        try {
            Object.entries(categoryBreakdown).forEach(([category, amount]) => {
                // Type checking for amount
                if (typeof amount !== 'number') {
                    console.warn(`Invalid amount for category ${category}:`, amount);
                    return;
                }

                // Only include expense categories (negative amounts)
                if (amount < 0) {
                    categories.push(category);
                    values.push(Math.abs(amount));  // Convert to positive for chart
                }
            });
        } catch (error) {
            console.error("Error processing category data:", error);
        }

        // Return early if no categories or all values are 0
        if (categories.length === 0 || values.every(v => v === 0)) {
            this.showNoDataMessage(this.categoryDistributionTarget);
            return;
        }

        const options = {
            series: values,
            labels: categories,
            chart: {
                type: 'donut',
                height: 350
            },
            colors: ['#4f46e5', '#16a34a', '#ef4444', '#f59e0b', '#3b82f6', '#8b5cf6', '#ec4899', '#0d9488', '#6b7280'],
            responsive: [{
                breakpoint: 480,
                options: {
                    chart: {
                        width: 300
                    },
                    legend: {
                        position: 'bottom'
                    }
                }
            }],
            tooltip: {
                y: {
                    formatter: function (val) {
                        return '$' + val.toFixed(2);
                    }
                }
            },
            plotOptions: {
                pie: {
                    donut: {
                        size: '65%',
                        labels: {
                            show: true,
                            name: {
                                show: true,
                                fontSize: '14px',
                                fontFamily: 'Helvetica, Arial, sans-serif',
                                fontWeight: 500,
                                color: '#111'
                            },
                            value: {
                                show: true,
                                fontSize: '16px',
                                fontFamily: 'Helvetica, Arial, sans-serif',
                                color: '#111',
                                formatter: function (val) {
                                    return '$' + parseFloat(val).toFixed(2);
                                }
                            },
                            total: {
                                show: true,
                                showAlways: true,
                                label: 'Total',
                                fontSize: '16px',
                                fontWeight: 600,
                                color: '#111',
                                formatter: function (w) {
                                    // Sum all values safely
                                    const total = w.globals.seriesTotals.reduce((a, b) => {
                                        // Ensure b is a number
                                        const numB = parseFloat(b);
                                        return a + (isNaN(numB) ? 0 : numB);
                                    }, 0);
                                    return '$' + total.toFixed(2);
                                }
                            }
                        }
                    }
                }
            }
        };

        try {
            this.categoryDistributionChart = new ApexCharts(this.categoryDistributionTarget, options);
            this.categoryDistributionChart.render();
            console.log("Category Distribution chart rendered successfully");
        } catch (error) {
            console.error("Error rendering Category Distribution chart:", error);
            this.showErrorMessage(this.categoryDistributionTarget);
        }
    }

    renderDayOfWeekChart() {
        if (!this.hasDayOfWeekTarget) {
            console.warn("Day of week target not found");
            return;
        }

        // Enhanced validation
        if (!this.trendsValue || !this.trendsValue.day_of_week_spending) {
            console.warn("Day of week spending data is missing");
            this.showNoDataMessage(this.dayOfWeekTarget);
            return;
        }

        const dayOfWeekSpending = this.trendsValue.day_of_week_spending;

        // If no day of the week data is available or invalid format
        if (!dayOfWeekSpending || Object.keys(dayOfWeekSpending).length === 0) {
            this.showNoDataMessage(this.dayOfWeekTarget);
            return;
        }

        // Format the data
        const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const data = [];

        try {
            // Convert to array format with type checking
            for (let i = 0; i < 7; i++) {
                // Get the amount, defaulting to 0 if missing or not a number
                let amount = dayOfWeekSpending[i];
                if (typeof amount !== 'number') {
                    amount = 0;
                }

                const dayAmount = Math.abs(amount);

                data.push({
                    x: dayNames[i],
                    y: dayAmount
                });
            }

            // Sort by amount descending
            data.sort((a, b) => b.y - a.y);
        } catch (error) {
            console.error("Error processing day of week data:", error);
            this.showErrorMessage(this.dayOfWeekTarget);
            return;
        }

        // If all days have zero spending, show a message
        if (data.every(day => day.y === 0)) {
            this.showNoDataMessage(this.dayOfWeekTarget);
            return;
        }

        const options = {
            series: [{
                name: 'Spending',
                data: data
            }],
            chart: {
                type: 'bar',
                height: 240,
                toolbar: {
                    show: false
                }
            },
            colors: ['#3b82f6'],
            plotOptions: {
                bar: {
                    horizontal: true,
                    barHeight: '70%',
                    borderRadius: 4
                }
            },
            dataLabels: {
                enabled: true,
                formatter: function(val) {
                    return '$' + val.toFixed(0);
                },
                style: {
                    fontSize: '12px'
                }
            },
            xaxis: {
                categories: data.map(item => item.x),
                labels: {
                    formatter: function(val) {
                        return '$' + val.toFixed(0);
                    }
                }
            },
            tooltip: {
                y: {
                    formatter: function(val) {
                        return '$' + val.toFixed(2);
                    }
                }
            }
        };

        try {
            this.dayOfWeekChart = new ApexCharts(this.dayOfWeekTarget, options);
            this.dayOfWeekChart.render();
            console.log("Day of Week chart rendered successfully");
        } catch (error) {
            console.error("Error rendering Day of Week chart:", error);
            this.showErrorMessage(this.dayOfWeekTarget);
        }
    }

    // Helper methods for showing messages
    showNoDataMessage(target) {
        target.innerHTML = '<div class="text-center p-4 text-gray-500">No data available for this chart</div>';
    }

    showErrorMessage(target) {
        target.innerHTML = '<div class="text-center p-4 text-gray-500">Error rendering chart</div>';
    }

    disconnect() {
        if (this.incomeExpenseChart) {
            this.incomeExpenseChart.destroy();
        }
        if (this.categoryDistributionChart) {
            this.categoryDistributionChart.destroy();
        }
        if (this.dayOfWeekChart) {
            this.dayOfWeekChart.destroy();
        }
    }
}
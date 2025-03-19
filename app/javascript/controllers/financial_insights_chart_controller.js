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
        this.renderCharts();
    }

    renderCharts() {
        this.renderIncomeExpenseChart();
        this.renderCategoryDistributionChart();
        this.renderDayOfWeekChart();
    }

    renderIncomeExpenseChart() {
        if (!this.hasIncomeExpenseTarget || !this.trendsValue || !this.trendsValue.monthly_trends) return;

        const monthlyTrends = this.trendsValue.monthly_trends;

        // Convert data format to series for ApexCharts
        const months = [];
        const incomeData = [];
        const expensesData = [];
        const netData = [];

        monthlyTrends.forEach(month => {
            months.push(month.month);
            incomeData.push(month.income || 0);
            expensesData.push(Math.abs(month.expenses || 0)); // Convert to positive for chart
            netData.push(month.net || 0);
        });

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

        this.incomeExpenseChart = new ApexCharts(this.incomeExpenseTarget, options);
        this.incomeExpenseChart.render();
    }

    renderCategoryDistributionChart() {
        if (!this.hasCategoryDistributionTarget || !this.trendsValue || !this.trendsValue.category_breakdown) return;

        const categoryBreakdown = this.trendsValue.category_breakdown;

        // Convert data format to series for ApexCharts
        const categories = [];
        const values = [];

        Object.entries(categoryBreakdown).forEach(([category, amount]) => {
            // Only include expense categories (negative amounts)
            if (amount < 0) {
                categories.push(category);
                values.push(Math.abs(amount));  // Convert to positive for chart
            }
        });

        // Return early if no categories or all values are 0
        if (categories.length === 0 || values.every(v => v === 0)) {
            this.categoryDistributionTarget.innerHTML = '<div class="text-center p-4 text-gray-500">No category spending data available</div>';
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
        } catch (error) {
            console.error("Error rendering Category Distribution chart:", error);
            this.categoryDistributionTarget.innerHTML = '<div class="text-center p-4 text-gray-500">Error rendering chart</div>';
        }
    }

    renderDayOfWeekChart() {
        if (!this.hasDayOfWeekTarget || !this.trendsValue || !this.trendsValue.day_of_week_spending) return;

        const dayOfWeekSpending = this.trendsValue.day_of_week_spending;

        // If no day of week data is available
        if (!dayOfWeekSpending || Object.keys(dayOfWeekSpending).length === 0) {
            this.dayOfWeekTarget.innerHTML = '<div class="text-center p-4 text-gray-500">No day of week data available</div>';
            return;
        }

        // Format the data
        const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const data = [];

        // Convert to array format
        for (let i = 0; i < 7; i++) {
            const dayAmount = Math.abs(dayOfWeekSpending[i] || 0);
            data.push({
                x: dayNames[i],
                y: dayAmount
            });
        }

        // Sort by amount descending
        data.sort((a, b) => b.y - a.y);

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

        this.dayOfWeekChart = new ApexCharts(this.dayOfWeekTarget, options);
        this.dayOfWeekChart.render();
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
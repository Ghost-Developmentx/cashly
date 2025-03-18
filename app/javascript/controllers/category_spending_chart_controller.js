import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static values = {
        data: Object
    }

    connect() {
        console.log("Category Spending Controller Connected", this.dataValue);

        if (!this.dataValue) {
            console.error("No data provided to Category Spending chart");
            // Add a message to the element
            this.element.innerHTML = '<div class="text-center p-4 text-gray-500">No category spending data available</div>';
            return;
        }

        const data = this.dataValue;

        // Check if we have the expected structure
        if (!data.series || !data.labels || data.series.length === 0 || data.labels.length === 0) {
            console.error("Category Spending data format is invalid:", data);
            this.element.innerHTML = '<div class="text-center p-4 text-gray-500">Unable to display category data</div>';
            return;
        }

        // Ensure we have data to show
        if (data.series.every(value => value === 0)) {
            console.warn("Category Spending data is all zeros", data);
            this.element.innerHTML = '<div class="text-center p-4 text-gray-500">No spending data for the selected period</div>';
            return;
        }

        // Safe number formatter to handle non-numeric values
        const safeFormat = (val) => {
            // Check if val is a number or can be converted to one
            const num = parseFloat(val);
            if (isNaN(num)) {
                console.warn("Non-numeric value detected:", val);
                return "$0.00";
            }
            return "$" + num.toFixed(2);
        };

        const options = {
            series: data.series,
            labels: data.labels,
            chart: {
                type: 'donut',
                height: 380,
                fontFamily: 'Helvetica, Arial, sans-serif',
                animations: {
                    enabled: true,
                    easing: 'easeinout',
                    speed: 800
                },
                toolbar: {
                    show: false
                }
            },
            title: {
                text: 'Spending by Category',
                align: 'left',
                style: {
                    fontSize: '16px',
                    fontWeight: 'bold',
                    fontFamily: 'Helvetica, Arial, sans-serif',
                    color: '#263238'
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
                                    return safeFormat(val);
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
                                    return safeFormat(total);
                                }
                            }
                        }
                    }
                }
            },
            dataLabels: {
                enabled: false
            },
            legend: {
                position: 'bottom',
                horizontalAlign: 'center',
                fontSize: '13px',
                fontFamily: 'Helvetica, Arial, sans-serif',
                formatter: function(seriesName, opts) {
                    const value = opts.w.globals.series[opts.seriesIndex];
                    const numValue = parseFloat(value);

                    // Calculate total safely
                    const total = opts.w.globals.seriesTotals.reduce((a, b) => {
                        const numB = parseFloat(b);
                        return a + (isNaN(numB) ? 0 : numB);
                    }, 0);

                    // Calculate percentage safely
                    let percent = 0;
                    if (!isNaN(numValue) && total > 0) {
                        percent = ((numValue / total) * 100).toFixed(1);
                    }

                    return `${seriesName}: ${safeFormat(numValue)} (${percent}%)`;
                }
            },
            tooltip: {
                enabled: true,
                y: {
                    formatter: function (val) {
                        return safeFormat(val);
                    }
                }
            },
            responsive: [
                {
                    breakpoint: 480,
                    options: {
                        chart: {
                            height: 300
                        },
                        legend: {
                            position: 'bottom'
                        }
                    }
                }
            ],
            colors: [
                '#4f46e5', // Indigo
                '#ef4444', // Red
                '#16a34a', // Green
                '#f59e0b', // Amber
                '#3b82f6', // Blue
                '#8b5cf6', // Violet
                '#ec4899', // Pink
                '#0d9488', // Teal
                '#6b7280'  // Gray for Others
            ]
        };

        try {
            this.chart = new ApexCharts(this.element, options);
            this.chart.render();
            console.log("Category Spending chart rendered successfully");
        } catch (error) {
            console.error("Error rendering Category Spending chart:", error);
            this.element.innerHTML = '<div class="text-center p-4 text-gray-500">Error rendering chart</div>';
        }
    }

    disconnect() {
        if (this.chart) {
            this.chart.destroy();
        }
    }
}
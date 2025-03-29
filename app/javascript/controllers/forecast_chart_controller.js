import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static values = {
        forecastData: Object
    }

    connect() {
        if (!this.hasForecastDataValue) {
            this.showNoDataMessage();
            return;
        }

        const forecastData = this.forecastDataValue;

        // Validate data structure
        if (!forecastData || !forecastData.forecast || !Array.isArray(forecastData.forecast) || forecastData.forecast.length === 0) {
            console.error("Invalid forecast data:", forecastData);
            this.showNoDataMessage();
            return;
        }

        // Extract data with fallbacks
        const dates = forecastData.forecast.map(item => item.date || '');
        const balances = forecastData.forecast.map(item => item.balance || item.projected_balance || 0);
        const incomes = forecastData.forecast.map(item => item.income || 0);
        const expenses = forecastData.forecast.map(item => item.expenses || 0);

        const options = {
            series: [
                {
                    name: 'Balance',
                    data: balances,
                    type: 'line'
                },
                {
                    name: 'Income',
                    data: incomes,
                    type: 'column'
                },
                {
                    name: 'Expenses',
                    data: expenses.map(v => -Math.abs(v)), // Make expenses negative
                    type: 'column'
                }
            ],
            chart: {
                height: 400, // Increased height
                fontFamily: '"Inter", system-ui, sans-serif', // Modern font
                background: '#F9FAFB', // Light gray background
                toolbar: {
                    show: true,
                    tools: {
                        download: true,
                        selection: false,
                        zoom: true,
                        zoomin: true,
                        zoomout: true,
                        pan: true,
                        reset: true
                    }
                },
                animations: {
                    enabled: true,
                    easing: 'easeinout',
                    speed: 800,
                    animateGradually: {
                        enabled: true,
                        delay: 150
                    },
                    dynamicAnimation: {
                        enabled: true,
                        speed: 350
                    }
                }
            },
            plotOptions: {
                bar: {
                    columnWidth: '55%',
                    borderRadius: 4, // Rounded corners on bars
                    dataLabels: {
                        position: 'top'
                    }
                }
            },
            dataLabels: {
                enabled: false
            },
            xaxis: {
                categories: dates,
                labels: {
                    rotate: -45,
                    style: {
                        fontSize: '12px',
                        fontFamily: '"Inter", system-ui, sans-serif',
                        colors: '#64748B' // Slate color for better readability
                    },
                    trim: true,
                    maxHeight: 120
                },
                axisBorder: {
                    show: false
                },
                axisTicks: {
                    show: false
                }
            },
            yaxis: {
                title: {
                    text: 'Amount',
                    style: {
                        fontSize: '14px',
                        fontWeight: 500,
                        color: '#64748B'
                    }
                },
                labels: {
                    formatter: function(value) {
                        return '$' + Math.abs(value).toFixed(0);
                    },
                    style: {
                        fontSize: '12px',
                        colors: '#64748B'
                    }
                }
            },
            grid: {
                borderColor: '#E2E8F0',
                strokeDashArray: 5,
                padding: {
                    top: 0,
                    right: 0,
                    bottom: 0,
                    left: 10
                }
            },
            stroke: {
                curve: 'smooth',
                width: [4, 0, 0]  // Line width for balance, no line for columns
            },
            colors: ['#3b82f6', '#10b981', '#ef4444'], // Blue, Green, Red
            legend: {
                position: 'top',
                horizontalAlign: 'right',
                fontFamily: '"Inter", system-ui, sans-serif',
                fontSize: '14px',
                markers: {
                    width: 12,
                    height: 12,
                    radius: 12
                }
            },
            tooltip: {
                enabled: true,
                shared: true,
                intersect: false,
                y: {
                    formatter: function(value) {
                        return '$' + Math.abs(value).toFixed(2);
                    }
                },
                theme: 'light',
                style: {
                    fontSize: '12px',
                    fontFamily: '"Inter", system-ui, sans-serif'
                }
            },
            responsive: [
                {
                    breakpoint: 768,
                    options: {
                        chart: {
                            height: 300
                        },
                        legend: {
                            position: 'bottom',
                            horizontalAlign: 'center'
                        }
                    }
                }
            ],
            // Add annotations for today's date
            annotations: {
                xaxis: [{
                    x: new Date().toISOString().split('T')[0], // Today's date
                    borderColor: '#475569',
                    label: {
                        borderColor: '#475569',
                        style: {
                            color: '#fff',
                            background: '#475569'
                        },
                        text: 'Today'
                    }
                }]
            }
        };

        try {
            this.chart = new ApexCharts(this.element, options);
            this.chart.render();
        } catch(error) {
            console.error("Error rendering chart:", error);
            this.showErrorMessage();
        }
    }

    showNoDataMessage() {
        this.element.innerHTML = `
            <div class="flex flex-col items-center justify-center h-full p-8 bg-gray-50 rounded-lg border border-gray-200">
                <svg class="w-16 h-16 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                </svg>
                <p class="text-gray-600 text-center">No forecast data available. Please try creating a new forecast.</p>
            </div>
        `;
    }

    showErrorMessage() {
        this.element.innerHTML = `
            <div class="flex flex-col items-center justify-center h-full p-8 bg-red-50 rounded-lg border border-red-200">
                <svg class="w-16 h-16 text-red-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <p class="text-red-600 text-center">There was an error rendering the chart. Please try again later.</p>
            </div>
        `;
    }

    disconnect() {
        if (this.chart) {
            this.chart.destroy();
        }
    }
}
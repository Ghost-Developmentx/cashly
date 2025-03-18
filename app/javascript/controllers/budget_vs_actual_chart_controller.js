import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static values = {
        data: Object
    }

    connect() {
        if (!this.dataValue) return;

        const data = this.dataValue;

        // Check if we have the expected structure
        if (!data.categories || !data.series || !data.series.length) {
            console.error("Budget vs Actual data format is invalid:", data);
            return;
        }

        const options = {
            series: data.series,
            xaxis: {
                categories: data.categories,
                labels: {
                    style: {
                        fontSize: '12px',
                        fontFamily: 'Helvetica, Arial, sans-serif'
                    },
                    trim: true,
                    maxHeight: 120,
                    rotate: -45,
                    offsetY: 0
                },
                axisBorder: {
                    show: false
                },
                axisTicks: {
                    show: false
                }
            },
            yaxis: {
                labels: {
                    formatter: function(val) {
                        return '$' + val.toFixed(0);
                    },
                    style: {
                        fontSize: '12px',
                        fontFamily: 'Helvetica, Arial, sans-serif'
                    }
                }
            },
            colors: ['#4f46e5', '#ef4444'], // Indigo and Red
            title: {
                text: 'Budget vs Actual Spending',
                align: 'left',
                style: {
                    fontSize: '16px',
                    fontWeight: 'bold',
                    fontFamily: 'Helvetica, Arial, sans-serif',
                    color: '#263238'
                }
            },
            chart: {
                type: 'bar',
                height: 450, // Increased height
                toolbar: {
                    show: false
                },
                fontFamily: 'Helvetica, Arial, sans-serif',
                background: '#fff',
                animations: {
                    enabled: true,
                    easing: 'easeinout',
                    speed: 800
                }
            },
            plotOptions: {
                bar: {
                    horizontal: false,
                    columnWidth: '55%',
                    borderRadius: 4,
                    dataLabels: {
                        position: 'top'
                    }
                }
            },
            dataLabels: {
                enabled: true,
                formatter: function(val) {
                    return '$' + val.toFixed(0);
                },
                offsetY: -20,
                style: {
                    fontSize: '11px',
                    colors: ["#304758"]
                },
                background: {
                    enabled: true,
                    foreColor: '#fff',
                    padding: 4,
                    borderRadius: 2,
                    borderWidth: 1,
                    borderColor: '#fff',
                    opacity: 0.9
                }
            },
            legend: {
                position: 'top',
                horizontalAlign: 'right',
                floating: false,
                offsetY: -10,
                offsetX: 0
            },
            grid: {
                show: true,
                borderColor: '#f1f1f1',
                padding: {
                    bottom: 20
                }
            },
            tooltip: {
                shared: true,
                intersect: false,
                y: {
                    formatter: function (val) {
                        return "$" + val.toFixed(2);
                    }
                }
            }
        };

        this.chart = new ApexCharts(this.element, options);
        this.chart.render();
    }

    disconnect() {
        if (this.chart) {
            this.chart.destroy();
        }
    }
}
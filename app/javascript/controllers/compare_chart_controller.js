import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static values = {
        originalData: Object,
        comparisonData: Object
    }

    connect() {
        if (!this.hasOriginalDataValue || !this.hasComparisonDataValue) {
            this.showNoDataMessage();
            return;
        }

        const originalData = this.originalDataValue;
        const comparisonData = this.comparisonDataValue;

        // Validate data
        if (!this.validateData(originalData) || !this.validateData(comparisonData)) {
            console.error("Invalid comparison data");
            this.showNoDataMessage();
            return;
        }

        try {
            this.renderComparisonChart(originalData, comparisonData);
        } catch (error) {
            console.error("Error rendering comparison chart:", error);
            this.showErrorMessage();
        }
    }

    validateData(data) {
        return data && data.forecast && Array.isArray(data.forecast) && data.forecast.length > 0;
    }

    renderComparisonChart(originalData, comparisonData) {
        const dates = originalData.forecast.map(item => item.date || '');
        const originalBalances = originalData.forecast.map(item => item.balance || 0);
        const comparisonBalances = comparisonData.forecast.map(item => item.balance || 0);

        const options = {
            series: [
                {
                    name: originalData.name || 'Original Forecast',
                    data: originalBalances
                },
                {
                    name: comparisonData.name || 'Comparison Forecast',
                    data: comparisonBalances
                }
            ],
            chart: {
                height: 400,
                type: 'line',
                toolbar: {
                    show: true
                }
            },
            stroke: {
                curve: 'smooth',
                width: 3
            },
            colors: ['#3b82f6', '#10b981'], // Blue, Green
            xaxis: {
                categories: dates,
                labels: {
                    rotate: -45,
                    style: {
                        fontSize: '10px'
                    }
                }
            },
            yaxis: {
                title: {
                    text: 'Balance'
                },
                labels: {
                    formatter: function(value) {
                        return '$' + value.toFixed(0);
                    }
                }
            },
            markers: {
                size: 4
            },
            legend: {
                position: 'top'
            }
        };

        this.chart = new ApexCharts(this.element, options);
        this.chart.render();
    }

    showNoDataMessage() {
        this.element.innerHTML = '<div class="text-center p-4 text-gray-500">No comparison data available</div>';
    }

    showErrorMessage() {
        this.element.innerHTML = '<div class="text-center p-4 text-red-500">Error rendering comparison chart</div>';
    }

    disconnect() {
        if (this.chart) {
            this.chart.destroy();
        }
    }
}
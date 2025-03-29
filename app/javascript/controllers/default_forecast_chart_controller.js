import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static values = {
        forecastData: Object
    }

    connect() {
        console.log("Default Forecast Chart Controller Connected");

        try {
            // First, check if we have the data value
            if (!this.hasForecastDataValue) {
                console.warn("No default forecast data available");
                this.showNoDataMessage();
                return;
            }

            let forecastData = this.forecastDataValue;

            // Validate forecast data structure
            if (!forecastData || !forecastData.forecast || !Array.isArray(forecastData.forecast) || forecastData.forecast.length === 0) {
                console.error("Invalid default forecast data structure:", forecastData);
                this.showNoDataMessage();
                return;
            }

            // Extract data with fallbacks for missing values
            const dates = forecastData.forecast.map(item => item.date || '');
            const balances = forecastData.forecast.map(item => item.balance || item.projected_balance || 0);

            const options = {
                series: [{
                    name: 'Projected Balance',
                    data: balances
                }],
                chart: {
                    type: 'line',
                    height: 250,
                    toolbar: {
                        show: false
                    }
                },
                xaxis: {
                    categories: dates,
                    labels: {
                        style: {
                            fontSize: '10px'
                        }
                    }
                },
                stroke: {
                    curve: 'smooth',
                    width: 3
                },
                colors: ['#3b82f6'], // Blue color
                title: {
                    text: '30-Day Cash Flow Projection',
                    align: 'left',
                    style: {
                        fontSize: '14px'
                    }
                }
            };

            this.chart = new ApexCharts(this.element, options);
            this.chart.render();

        } catch (error) {
            console.error("Error rendering default forecast chart:", error);
            this.showErrorMessage();
        }
    }

    showNoDataMessage() {
        this.element.innerHTML = '<div class="text-center p-4 text-gray-500">No forecast data available</div>';
    }

    showErrorMessage() {
        this.element.innerHTML = '<div class="text-center p-4 text-red-500">Error rendering chart</div>';
    }

    disconnect() {
        if (this.chart) {
            this.chart.destroy();
        }
    }
}
import { Controller } from "@hotwired/stimulus"
import ApexCharts from "apexcharts";

export default class extends Controller {
    static values = {
        data: Object  // Changed from Array to Object
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
                categories: data.categories
            },
            colors: ['#4f46e5', '#ef4444'], // Indigo and Red
            title: {
                text: 'Budget vs Actual Spending',
                align: 'left'
            },
            chart: {
                type: 'bar',
                height: 350,
                toolbar: {
                    show: false
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
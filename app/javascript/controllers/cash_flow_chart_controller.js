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
        if (!data.dates || !data.series || !data.series.length) {
            console.error("Cash flow data format is invalid:", data);
            return;
        }

        const options = {
            series: data.series,
            xaxis: {
                categories: data.dates
            },
            colors: ['#3b82f6', '#10b981', '#ef4444'], // Blue, Green, Red for Net, Income, Expenses
            title: {
                text: 'Cash Flow Forecast',
                align: 'left'
            },
            chart: {
                type: 'line',
                height: 350,
                toolbar: {
                    show: false
                }
            },
            stroke: {
                curve: 'smooth',
                width: 3
            },
            markers: {
                size: 4
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
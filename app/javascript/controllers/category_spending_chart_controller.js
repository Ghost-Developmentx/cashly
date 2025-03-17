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
        if (!data.series || !data.labels || !data.series.length) {
            console.error("Category spending data format is invalid:", data);
            return;
        }

        const options = {
            series: data.series,
            labels: data.labels,
            chart: {
                type: 'pie',
                height: 350,
                toolbar: {
                    show: false
                }
            },
            title: {
                text: 'Spending by Category',
                align: 'left'
            },
            legend: {
                position: 'bottom'
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
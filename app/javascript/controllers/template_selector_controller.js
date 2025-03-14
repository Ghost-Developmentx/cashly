// app/javascript/controllers/template_selector_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["template", "container"]

    connect() {
        // Highlight the initially selected template
        this.highlightSelected();

        // Add event listeners to all template radio buttons
        this.templateTargets.forEach(template => {
            template.addEventListener('change', () => this.highlightSelected());
        });
    }

    highlightSelected() {
        // Remove highlight from all containers
        this.containerTargets.forEach(container => {
            container.classList.remove('selected-template');
        });

        // Find the checked radio button
        const checkedTemplate = this.templateTargets.find(template => template.checked);

        if (checkedTemplate) {
            // Get the corresponding container
            const containerId = checkedTemplate.value;
            const selectedContainer = this.containerTargets.find(
                container => container.dataset.templateId === containerId
            );

            if (selectedContainer) {
                // Add highlight class
                selectedContainer.classList.add('selected-template');
            }
        }
    }
    }
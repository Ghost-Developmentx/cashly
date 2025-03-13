// app/javascript/controllers/invoice_preview_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "template", "previewFrame", "clientName", "clientEmail", "clientAddress",
        "amount", "currency", "issueDate", "dueDate", "description", "notes", "terms",
        "logoInput", "logoPreview", "removeLogo", "companyName"
    ]

    connect() {
        // Initialize preview
        this.debounceTimer = null;
        this.updatePreview();

        // Setup event listeners for all form fields
        this.setupFieldListeners();
    }

    setupFieldListeners() {
        // Add input event listeners to all form fields
        this.templateTargets.forEach(element => {
            element.addEventListener('change', () => this.updatePreview());
        });

        // Text fields with debounce
        const textFields = [
            this.clientNameTarget, this.clientEmailTarget, this.clientAddressTarget,
            this.amountTarget, this.descriptionTarget, this.notesTarget, this.termsTarget,
            this.companyNameTarget
        ];

        textFields.forEach(field => {
            if (field) {
                field.addEventListener('input', () => this.debounceUpdatePreview());
            }
        });

        // Select fields
        const selectFields = [this.currencyTarget];
        selectFields.forEach(field => {
            if (field) {
                field.addEventListener('change', () => this.updatePreview());
            }
        });

        // Date fields
        const dateFields = [this.issueDateTarget, this.dueDateTarget];
        dateFields.forEach(field => {
            if (field) {
                field.addEventListener('change', () => this.updatePreview());
            }
        });
    }

    debounceUpdatePreview() {
        clearTimeout(this.debounceTimer);
        this.debounceTimer = setTimeout(() => {
            this.updatePreview();
        }, 300); // 300ms debounce
    }

    updatePreview() {
        const formData = new FormData();
        const selectedTemplate = document.querySelector('input[name="invoice[template]"]:checked').value;

        // Add all form field values to formData
        formData.append('template', selectedTemplate);

        if (this.clientNameTarget) formData.append('client_name', this.clientNameTarget.value);
        if (this.clientEmailTarget) formData.append('client_email', this.clientEmailTarget.value);
        if (this.clientAddressTarget) formData.append('client_address', this.clientAddressTarget.value);
        if (this.amountTarget) formData.append('amount', this.amountTarget.value);
        if (this.currencyTarget) formData.append('currency', this.currencyTarget.value);
        if (this.issueDateTarget) formData.append('issue_date', this.issueDateTarget.value);
        if (this.dueDateTarget) formData.append('due_date', this.dueDateTarget.value);
        if (this.descriptionTarget) formData.append('description', this.descriptionTarget.value);
        if (this.notesTarget) formData.append('notes', this.notesTarget.value);
        if (this.termsTarget) formData.append('terms', this.termsTarget.value);
        if (this.companyNameTarget) formData.append('company_name', this.companyNameTarget.value);

        // Handle logo if it's been uploaded
        if (this.logoInputTarget && this.logoInputTarget.files.length > 0) {
            formData.append('logo', this.logoInputTarget.files[0]);
        }

        // Get CSRF token from meta tag
        const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

        // Send AJAX request to get preview HTML
        fetch('/invoices/preview_template', {
            method: 'POST',
            headers: {
                'X-CSRF-Token': csrfToken,
            },
            body: formData
        })
            .then(response => response.text())
            .then(html => {
                // Update the preview iframe
                const iframe = this.previewFrameTarget;
                const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                iframeDoc.open();
                iframeDoc.write(html);
                iframeDoc.close();
            })
            .catch(error => {
                console.error('Error updating preview:', error);
            });
    }

    // Handle logo upload
    handleLogoUpload(event) {
        const file = event.target.files[0];
        if (file) {
            const reader = new FileReader();

            reader.onload = (e) => {
                // Show the logo preview
                this.logoPreviewTarget.src = e.target.result;
                this.logoPreviewTarget.classList.remove('d-none');
                this.removeLogoTarget.classList.remove('d-none');

                // Update the preview with the logo
                this.updatePreview();
            };

            reader.readAsDataURL(file);
        }
    }

    // Remove logo
    removeLogo() {
        this.logoInputTarget.value = '';
        this.logoPreviewTarget.src = '';
        this.logoPreviewTarget.classList.add('d-none');
        this.removeLogoTarget.classList.add('d-none');

        // Update the preview without the logo
        this.updatePreview();
    }
}
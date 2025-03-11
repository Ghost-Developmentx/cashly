/** @type {any} */
/* global Plaid */

document.addEventListener('DOMContentLoaded', function () {
    const plaidButton = document.getElementById('plaid-link-button')

    if (plaidButton) {
        plaidButton.addEventListener('click', function () {
            // First, get a link token from our server
            fetch("/plaid/create_link_token", {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')
                }
            })
                .then(response => response.json())
                .then(data => {
                    const linkToken = data.link_token;

                    // Initialize Plaid Token
                    const handler = Plaid.create({
                        token: linkToken,
                        onSuccess: (public_token, metadata) => {
                            // Send public_token to our server
                            fetch('/plaid/exchange_public_token', {
                                method: 'POST',
                                headers: {
                                    'Content-Type': 'application/json',
                                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                                },
                                body: JSON.stringify({public_token: public_token})
                            })
                                .then(response => response.json())
                                .then(data => {
                                    if (data.success) {
                                        window.location.href = '/accounts';
                                    }
                                });
                        },
                        onExit: (err, metadata) => {
                            if (err != null) {
                                console.error("Error during link flow:", err)
                            }
                        },
                        onEvent: (eventName, metadata) => {
                            console.log('Event:', eventName)
                        }

                    });

                    handler.open();
                })
        })
    }
})
// Listen for both initial page load and Turbo navigation
document.addEventListener('turbo:load', initPlaidLink);
document.addEventListener('DOMContentLoaded', initPlaidLink);

// Avoid duplicate initializations
let plaidInitialized = false;

function initPlaidLink() {
    const plaidButton = document.getElementById('plaid-link-button');

    if (plaidButton) {
        // Remove any existing click listeners to prevent duplicates
        const newButton = plaidButton.cloneNode(true);
        plaidButton.parentNode.replaceChild(newButton, plaidButton);

        newButton.addEventListener('click', function() {
            console.log("Plaid button clicked, fetching link token...");

            // Get link token from our server
            fetch("/plaid/create_link_token", {
                method: "POST",
                headers: {
                    'Content-Type': 'application/json',
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
                }
            })
                .then(response => response.json())
                .then(data => {
                    if (!data.token) {
                        console.error("Failed to get link token:", data);
                        alert("Failed to connect to banking services. Please try again later.");
                        return;
                    }

                    const linkToken = data.token;
                    console.log("Link token received, opening Plaid Link...");

                    // Initialize Plaid Link with the token
                    const handler = Plaid.create({
                        token: linkToken,
                        onSuccess: (public_token, metadata) => {
                            console.log("Link success - public token received");

                            // Send public token to our server
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
                                    } else {
                                        console.error("Failed to exchange public token:", data);
                                        alert("Connection established, but we couldn't complete account setup. Please try again.");
                                    }
                                })
                                .catch(error => {
                                    console.error("Error exchanging public token:", error);
                                    alert("Connection established, but we couldn't complete account setup. Please try again.");
                                });
                        },
                        onExit: (err, metadata) => {
                            if (err != null) {
                                console.error("Link exit with error:", err, metadata);
                            }
                        },
                        onEvent: (eventName, metadata) => {
                            console.log("Link event:", eventName, metadata);
                        }
                    });

                    handler.open();
                })
                .catch(error => {
                    console.error("Error creating link token:", error);
                    alert("Failed to connect to banking services. Please try again later.");
                });
        });
    }
}
document.addEventListener('DOMContentLoaded', function () {
    const plaidButton = document.getElementById('plaid-link-button')

    if (plaidButton) {
        plaidButton.addEventListener('click', function () {
            // Get link token from our server
            fetch("plaid/create_link_token", {
                method: "POST",
                headers: {
                    'Content-Type': 'application/json',
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
                }
            })
                .then(response => response.json())
                .then(data => {
                    if (!data.token) {
                        console.error("Failed to get link token:", data)
                        alert("Failed to connect to banking services. Please try again later.")
                        return;
                    }

                    const linkToken = data.token

                    // Initialize Plaid Link with the token
                    const handler = Plaid.create({
                        token: linkToken,
                        onSuccess: (public_token, metadata) => {
                            console.log("Link success - public token:", public_token);
                            console.log("Link success - metadata:", metadata);

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
                                        alert("Connection established, but we couldn't complete account setup. Please try again.")
                                    }
                                })
                                .catch(error => {
                                    console.error("Error exchanging public token:", error);
                                    alert("Connection established, but we couldn't complete account setup. Please try again.")
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

                    handler.open()
                })
                .catch(error => {
                    console.error("Error creating link token:", error);
                    alert("Failed to connect to banking services. Please try again later.")
                })
        })
    }
})
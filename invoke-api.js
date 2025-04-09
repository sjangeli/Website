// Replace with your API Gateway endpoint URL
const apiUrl = 'https://b8xtrjehn4.execute-api.us-east-1.amazonaws.com/prod/visitor-counter';

async function invokeApi() {
    try {
        // Make a GET request to the API Gateway endpoint
        const response = await fetch(apiUrl, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            },
            mode: 'cors' // Ensure CORS mode is enabled
        });

        // Check if the response is successful
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        // Parse the JSON response
        const data = await response.json();
        console.log('Response from API Gateway:', data);

        // Extract the current_count variable directly from the response
        const currentCount = data.current_count;
        console.log('Current Count:', currentCount);

        // Update the UI with the current_count
        document.getElementById('api-response').innerText = `Visitor Count: ${currentCount}`;
    } catch (error) {
        console.error('Error invoking API Gateway:', error);
        document.getElementById('api-response').innerText = 'Error invoking API Gateway';
    }
}

// Call the function to invoke the API
invokeApi();
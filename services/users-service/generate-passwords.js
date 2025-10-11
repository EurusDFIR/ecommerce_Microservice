const bcrypt = require('bcryptjs');

// Generate hashed passwords for demo users
const generateHashedPasswords = async () => {
    const passwords = {
        'admin123': await bcrypt.hash('admin123', 10),
        'customer123': await bcrypt.hash('customer123', 10)
    };
    
    console.log('Generated Hashed Passwords:');
    console.log('===========================');
    console.log(`admin123    => ${passwords.admin123}`);
    console.log(`customer123 => ${passwords.customer123}`);
    console.log('\nReplace these in app.js users array');
};

generateHashedPasswords();
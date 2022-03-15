const { v4 } = require("uuid");
const { dbFunctions } = require("./db");

const createOrder = async (event) => {
  const { name, email } = event.request.userAttributes;

  let date = new Date();

  const data = { name, email, date: date.toISOString() };

  const result = await dbFunctions.put(data);

  return {
    statusCode: 200,
    body: JSON.stringify(data),
  };
};

module.exports = {
  handler: createOrder,
};

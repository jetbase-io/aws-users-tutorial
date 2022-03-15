const { dbFunctions } = require("./db");

const getOrders = async () => {
  const result = await dbFunctions.getAll();

  return {
    statusCode: 200,
    body: JSON.stringify(result.Items),
  };
};

module.exports = {
  handler: getOrders,
};

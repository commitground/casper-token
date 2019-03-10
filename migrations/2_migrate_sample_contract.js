const CasperToken = artifacts.require('./CasperToken.sol')

module.exports = function (deployer) {
  deployer.deploy(CasperToken, 'CasperToken', 'CPT', 18)
}

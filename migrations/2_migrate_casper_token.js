const OverflowPriorityGenerator = artifacts.require('./Casper.sol')
const CasperToken = artifacts.require('./ERC1XXX.sol')

module.exports = function (deployer) {
  deployer.deploy(OverflowPriorityGenerator)
  deployer.link(OverflowPriorityGenerator, CasperToken)
  deployer.deploy(CasperToken, 'CasperToken', 'CPT', 18, web3.utils.toWei('10'))
}

const Casper = artifacts.require('./Casper')
const ERC1XXX = artifacts.require('./ERC1XXX')

module.exports = function (deployer) {
  deployer.deploy(Casper)
  deployer.link(Casper, ERC1XXX)
  deployer.deploy(
    ERC1XXX,
    'CasperToken',
    'CPT',
    18,
    web3.utils.toWei('10'),
    10368000,
    540
  )
}

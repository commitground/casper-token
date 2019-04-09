const CasperLib = artifacts.require('./Casper')
const ERC1913 = artifacts.require('./ERC1913')

module.exports = function (deployer) {
  deployer.deploy(CasperLib)
  deployer.link(CasperLib, ERC1913)
  deployer.deploy(
    ERC1913,
    'CasperPEPoWToken',
    'CPT',
    18,
    web3.utils.toWei('10'),
    10368000,
    540
  )
}

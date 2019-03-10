const chai = require('chai')
const BigNumber = web3.BigNumber
chai.use(require('chai-bignumber')(BigNumber)).should()
const CasperToken = artifacts.require('CasperToken')
chai.use(require('chai-bignumber')(BigNumber)).should()

contract('CasperToken', ([deployer, ...members]) => {
  let casperToken
  context('Test', async () => {
    beforeEach('Deploy new contract', async () => {
      casperToken = await CasperToken.new('CasperToken', 'CTK', 18)
    })
  })
})

const chai = require('chai')
const BigNumber = web3.BigNumber
chai.use(require('chai-bignumber')(BigNumber)).should()
const ERC1XXX = artifacts.require('ERC1XXX')
const Casper = artifacts.require('Casper')

contract('ERC1XXX', ([deployer, ...members]) => {
  let casperToken
  before('Deploy library', async () => {
    let casper = await Casper.new()
    await ERC1XXX.link(Casper, casper.address)
  })
  context('Test', async () => {
    beforeEach('Deploy new contract', async () => {
      casperToken = await ERC1XXX.new(
        'CasperToken',
        'CPT',
        18,
        web3.utils.toWei('10'),
        10368000,
        540
      )
    })
    it('should follow ERC20 standard', async () => {
      let currentBalance = await casperToken.balanceOf(members[0])
      currentBalance.isZero().should.equal(true)
    })
  })
})

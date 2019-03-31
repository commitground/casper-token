const chai = require('chai')
const BigNumber = web3.BigNumber
chai.use(require('chai-bignumber')(BigNumber)).should()
const CasperToken = artifacts.require('ERC1XXX')
const OverflowPriorityGenerator = artifacts.require('OverflowPriorityGenerator')

contract('CasperToken', ([deployer, ...members]) => {
  let casperToken
  before('Deploy library', async () => {
    let priorityLib = await OverflowPriorityGenerator.new()
    await CasperToken.link(OverflowPriorityGenerator, priorityLib.address)
  })
  context('Test', async () => {
    beforeEach('Deploy new contract', async () => {
      casperToken = await CasperToken.new('CasperToken', 'CTK', 18, web3.utils.toWei('10'))
    })
  })
  context('priority should be random as possible', async () => {
    before('Deploy new contract', async () => {
      casperToken = await CasperToken.new('CasperToken', 'CTK', 18, web3.utils.toWei('10'))
      for (let member of members) {
        await casperToken.participate({ from: member, value: web3.utils.toWei('10') })
      }
    })
  })
})

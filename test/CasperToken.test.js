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
    describe('deposit()', async () => {
      it('should emit a Deposit event', async () => {
        const STAKE = web3.utils.toWei('32')
        let initialBalance = await web3.eth.getBalance(casperToken.address)
        let receipt = await casperToken.deposit(
          { from: members[0], value: STAKE }
        )
        let updatedBalance = await web3.eth.getBalance(casperToken.address)
        let log = receipt.logs[0]
        log.event.should.equal('Deposit')
        log.args._from.should.equal(members[0])
        log.args._amount.toString().should.equal(STAKE)
        log.args._startDynasty.toString().should.equal('0')
        STAKE.should.equal((updatedBalance - initialBalance).toString())
      })
    })
    describe('requestWithdraw()', async () => {
    })
    describe('withdraw()', async () => {
    })
    describe('propose()', async () => {
    })
    describe('vote()', async () => {
    })
    describe('pushVoteMsg()', async () => {
    })
    describe('batchVote()', async () => {
    })
    describe('challenge()', async () => {
    })
    describe('justify()', async () => {
    })
    describe('slash()', async () => {
    })
  })
})

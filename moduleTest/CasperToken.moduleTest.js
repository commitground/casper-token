const Web3 = require('web3')
const chai = require('chai')
chai.use(require('chai-bignumber')()).should()

const { CasperToken } = require('../build/index.tmp')
const web3Provider = new Web3.providers.HttpProvider('http://localhost:8546')
const web3 = new Web3(web3Provider)

describe(
  'casper-token javascript library',
  () => {
    let accounts
    before(async () => {
      accounts = await web3.eth.getAccounts()
      web3.eth.defaultAccount = accounts[0]
    })
    context('CasperToken contract is deployed and it returns truffle-contract instance', () => {
      let casperToken
      before(async () => { casperToken = await CasperToken(web3).deployed() })
      it('should return zero for its initial balance', async () => {
        let currentBalance = await casperToken.balanceOf(accounts[0])
        currentBalance.eqn(0).should.equal(true)
      })
    })
  })

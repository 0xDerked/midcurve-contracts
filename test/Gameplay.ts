import hre from 'hardhat'
import { expect } from 'chai'
import { loadFixture, time } from '@nomicfoundation/hardhat-network-helpers'

import { parseEther, createWalletClient, http, zeroAddress } from 'viem'
import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts'

import fs from 'fs'
import { StandardMerkleTree } from '@openzeppelin/merkle-tree'

//This might yell at you if contracts have not been compiled with hardhat yet -- just run npx hardhat compile to generate the artifacts
import {
    GetContractReturnType,
    PublicClient,
    WalletClient,
} from '@nomicfoundation/hardhat-viem/types'
import { Midcurve$Type } from '../artifacts/contracts/Midcurve.sol/Midcurve'

type Midcurve = GetContractReturnType<Midcurve$Type['abi']>

describe('Midcurve', () => {
    const MidcurveLockFixture = async () => {
        const [owner, contributor] = await hre.viem.getWalletClients()

        const midcurve: Midcurve = await hre.viem.deployContract('Midcurve', [
            owner.account.address,
            contributor.account.address,
        ])
        return { midcurve }
    }

    describe('1k player test', () => {
        let midcurve: Midcurve
        let pubClient: PublicClient
        let fundingWallet: WalletClient
        let playerWallets: WalletClient[]
        let merkleTree: StandardMerkleTree<string[]>

        before(async () => {
            const contracts = await loadFixture(MidcurveLockFixture)
            midcurve = contracts.midcurve
            pubClient = await hre.viem.getPublicClient()
            const wallets = await hre.viem.getWalletClients()
            fundingWallet = wallets[0]
            playerWallets = []
        })

        it('creates 1k wallets and funds them', async () => {
            for (let i = 0; i < 1000; i++) {
                const newWallet = createWalletClient({
                    account: privateKeyToAccount(generatePrivateKey()),
                    chain: pubClient.chain,
                    transport: http(),
                })
                await fundingWallet.sendTransaction({
                    to: newWallet.account.address,
                    value: parseEther('1'),
                })
                playerWallets.push(newWallet)
            }
            expect(playerWallets.length).to.equal(1000)
        })

        it('begins the game', async () => {
            await midcurve.write.beginGame()
        })

        it('submit 1k dummy transactions from the player wallets', async () => {
            for (let playerWallet of playerWallets) {
                await midcurve.write.submit(['abc123', zeroAddress], {
                    account: playerWallet.account,
                    value: parseEther('0.02'),
                })
            }
        })

        it('create a merkle tree', async () => {
            const prizes = fs.readFileSync('./test/prizes1k.txt', 'utf8').trim().split('\n')
            const leaves = []
            for (let i = 0; i < prizes.length; i++) {
                leaves.push([playerWallets[i].account.address, prizes[i]])
            }
            merkleTree = StandardMerkleTree.of(leaves, ['address', 'uint256'])
        })

        it('fast forward the game and submit the merkle root', async () => {
            const expiryTime = await midcurve.read.expiryTimeAnswer()
            await time.increaseTo(expiryTime + 1n)
            await midcurve.write.gradeRound([merkleTree.root as '0x{string}'])
            const merkleRootContract = await midcurve.read.merkleRoot()
            expect(merkleRootContract).to.equal(merkleTree.root)
        })

        it('checks a few random claims', async () => {
            const addr7 = playerWallets[7].account.address
            for (const [i, v] of merkleTree.entries()) {
                if (v[0] === addr7) {
                    const proof = merkleTree.getProof(i) as '0xstring'[]
                    const claim = await midcurve.read.availableToClaim([proof, BigInt(v[1]), addr7])
                    console.log(claim)
                }
            }
        })
    })
})

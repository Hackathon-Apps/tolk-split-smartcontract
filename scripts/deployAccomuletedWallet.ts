import { Address, toNano, beginCell, SendMode } from '@ton/core';
import { AccomuletedWallet } from '../wrappers/AccomuletedWallet';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const accomuletedWallet = provider.open(
        AccomuletedWallet.createFromConfig(
            {
                id: Math.floor(Math.random() * 10000),
                goal: { kind: 'Coins', grams: toNano('0.5') },
                recieverAddress: Address.parse("UQB3pqex4lL1xQEW366-51VnMpP3fDYQe1DM3ij4qdOT8uxT"),
                creatorAddress: provider.sender().address!,
                feeCollectorAddress: provider.sender().address!,
                contributions: null,
            },
            await compile('AccomuletedWallet')
        )
    );

    const contributionBody = beginCell()
        .storeUint(0xCF4D2AC0, 32) // Contribution tag from accomuleted_wallet.tolk
        .storeUint(0, 64) // queryId = 0
        .endCell();

    await provider.sender().send({
        to: accomuletedWallet.address,
        value: toNano('0.1'),
        init: accomuletedWallet.init, // StateInit (code + data)
        body: contributionBody,
        sendMode: SendMode.PAY_GAS_SEPARATELY,
    });

    await provider.waitForDeploy(accomuletedWallet.address);

    console.log('ID', await accomuletedWallet.getID());
}

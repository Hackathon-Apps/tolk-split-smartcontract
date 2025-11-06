import { Address, toNano } from '@ton/core';
import { AccomuletedWallet } from '../wrappers/AccomuletedWallet';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const accomuletedWallet = provider.open(
        AccomuletedWallet.createFromConfig(
            {
                id: Math.floor(Math.random() * 10000),
                goal: { kind: 'Coins', grams: toNano('0.1') },
                recieverAddress: Address.parse("UQB3pqex4lL1xQEW366-51VnMpP3fDYQe1DM3ij4qdOT8uxT"),
                creatorAddress: provider.sender().address!,
            },
            await compile('AccomuletedWallet')
        )
    );

    await accomuletedWallet.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(accomuletedWallet.address);

    console.log('ID', await accomuletedWallet.getID());
}

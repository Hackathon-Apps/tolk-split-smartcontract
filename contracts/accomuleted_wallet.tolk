tolk 1.0

const REFUND_BATCH : int = 32
const PAYOUT_FEE_RESERVE : coins = 5000000  // reserve to cover network fees during payout (0.005 TON)
const PLATFORM_FEE_PERCENT : int = 5
const PERCENT_DENOMINATOR : int = 100

struct Storage {
    id: uint32
    goal: coins
    recieverAddress: address
    creatorAddress: address
    feeCollectorAddress: address
    contributions: map<address, coins>
}

fun Storage.load() {
    return Storage.fromCell(contract.getData());
}

fun Storage.save(self) {
    contract.setData(self.toCell());
}

struct (0xCF4D2AC0) Contribution {
    queryId: uint64
}

struct (0x61A586E5) Refund {
    queryId: uint64
}

type AllowedMessage = Contribution | Refund

fun addContribution(storage: Storage, address: address, amount: coins) {
    var contribution = storage.contributions.get(address);
    val value = contribution.isFound ? contribution.loadValue() + amount : amount;
    if (contribution.isFound == false) {
        storage.contributions.addIfNotExists(address, value);
    } else {
        storage.contributions.set(address, value);
    }
    Storage.save(storage);
}

fun getTotalContributions(storage: Storage): coins {
    var total: coins = 0;
    var iter = storage.contributions.findFirst();

    while (iter.isFound == true) {
        total = total + iter.loadValue();
        iter = storage.contributions.iterateNext(iter);
    }

    return total;
}

fun calculateReceiverTransferBase(storage: Storage): coins {
    if (storage.goal <= PAYOUT_FEE_RESERVE) {
        return 0;
    }
    return storage.goal - PAYOUT_FEE_RESERVE;
}

fun calculatePlatformFee(amount: coins): coins {
    if (amount <= 0) {
        return 0;
    }
    return (amount * PLATFORM_FEE_PERCENT) / PERCENT_DENOMINATOR;
}

fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessage.fromSlice(in.body);
    var storage = lazy Storage.load();

    match (msg) {
        Contribution => {
            val totalContributionsBefore = getTotalContributions(storage);
            val totalContributions = totalContributionsBefore + in.valueCoins;

            addContribution(storage, in.senderAddress, in.valueCoins);

            if (totalContributions >= storage.goal) {
                val receiverTransferBase = calculateReceiverTransferBase(storage);
                val platformFeeAmount = calculatePlatformFee(receiverTransferBase);
                val receiverAmount = receiverTransferBase - platformFeeAmount;

                if (receiverAmount > 0) {
                    val payReciever = createMessage({
                        value: receiverAmount,
                        bounce: false,
                        dest: storage.recieverAddress,
                    });
                    payReciever.send(SEND_MODE_REGULAR);
                }

                if (platformFeeAmount > 0) {
                    val payPlatform = createMessage({
                        value: platformFeeAmount,
                        bounce: false,
                        dest: storage.feeCollectorAddress,
                    });
                    payPlatform.send(SEND_MODE_REGULAR);
                }

                val excessCoins = totalContributions - storage.goal;
                if (excessCoins > 0) {
                    val payCreator = createMessage({
                        value: excessCoins,
                        bounce: false,
                        dest: storage.creatorAddress,
                    });
                    payCreator.send(SEND_MODE_REGULAR);
                }
            }
            return;
        }
        Refund => {
            var count: int = 0;
            var iterCurrent = storage.contributions.findFirst();

            while (count < REFUND_BATCH && iterCurrent.isFound == true) {
                val contributorAddress = iterCurrent.getKey();
                val contributionAmount = iterCurrent.loadValue();
                val payRefund = createMessage({
                    value: contributionAmount,
                    bounce: false,
                    dest: contributorAddress,
                });
                payRefund.send(SEND_MODE_REGULAR);
                count = count + 1;
                iterCurrent = storage.contributions.iterateNext(iterCurrent);
            }

            Storage.save(storage);
            return;
        }
        else => {
            return;
        }
    }
}

fun onBouncedMessage(in: InMessageBounced) {}

get fun getId(): uint32 {
    val storage = lazy Storage.load();
    return storage.id;
}

get fun goal(): coins {
    val storage = lazy Storage.load();
    return storage.goal;
}

get fun recieverAddress(): address {
    val storage = lazy Storage.load();
    return storage.recieverAddress;
}

get fun creatorAddress(): address {
    val storage = lazy Storage.load();
    return storage.creatorAddress!;
}

get fun feeCollectorAddress(): address {
    val storage = lazy Storage.load();
    return storage.feeCollectorAddress;
}

# Pancake Multisig Wallet
A general purpose multisig wallet

## Usage

1. Initialize your aptos account
```shell
$ aptos init
```
you will get a `.aptos` folder in your current folder.
```yaml
profiles:
  default:
    private_key: "0x3e81a207ca6e4eba285fd675a5a307c2dcb3ec2bf4342867cb4d2fd9d8c264a2"
    public_key: "0xf72b1239e54475f854265b01e6e7a7344ce602ff5461a39b83b56584067dd3b7"
    account: da9db7c9bda8b077db0b6e5ef7c6afd8ccdad84ba06fd9b96c789dce64cfe939 # this is your account
    rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
    faucet_url: "https://faucet.devnet.aptoslabs.com/"
```

2. Get some test APTs
```shell
$ aptos account fund-with-faucet --account YOUR_ACCOUNT --amount 1000000000000
```

> You can jump straight to the last step if you plan to use the deployed package
> by the official pancake team

3. Create a resource account for `pancake_multisig_wallet`
```shell
$ aptos move run --function-id '0x1::resource_account::create_resource_account_and_fund' --args 'string:pancake_multisig_wallet' 'hex:' 'u64:10000000'
```

4. Find the address of the resource account
```shell
$ aptos account list --query resources
```

```txt
{
  "0x1::resource_account::Container": {
    "store": {
      "data": [
        {
          "key": "0x86b448e60e65e6b0012ec160fa814a094adea060f000ee2034b2d208a443574",
          "value": {
            "account": "0x86b448e60e65e6b0012ec160fa814a094adea060f000ee2034b2d208a443574" # this is it, pad zeros to the left if it's shorter than 64 hex chars
          }
        }
      ]
    }
  }
}
```

Or find it on explorer: `https://explorer.devnet.aptos.dev/account/YOUR_ACCOUNT`

5. Add the resource account in `config.yaml`
```yaml
profiles:
  default:
    private_key: "0x3e81a207ca6e4eba285fd675a5a307c2dcb3ec2bf4342867cb4d2fd9d8c264a2"
    public_key: "0xf72b1239e54475f854265b01e6e7a7344ce602ff5461a39b83b56584067dd3b7"
    account: da9db7c9bda8b077db0b6e5ef7c6afd8ccdad84ba06fd9b96c789dce64cfe939
    rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
    faucet_url: "https://faucet.devnet.aptoslabs.com/"
  pancake_multisig_wallet:
    private_key: "0x3e81a207ca6e4eba285fd675a5a307c2dcb3ec2bf4342867cb4d2fd9d8c264a2"
    public_key: "0xf72b1239e54475f854265b01e6e7a7344ce602ff5461a39b83b56584067dd3b7"
    account: # add here
    rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
    faucet_url: "https://faucet.devnet.aptoslabs.com/"
```

6. Edit `Move.toml`
  ```toml
[package]
name = "PancakeMultisigWallet"
version = "0.0.1"

# .......
# .......
# .......

[addresses]
pancake_multisig_wallet = "086b448e60e65e6b0012ec160fa814a094adea060f000ee2034b2d208a443574" # replace with the resource account
pancake_multisig_wallet_dev = "da9db7c9bda8b077db0b6e5ef7c6afd8ccdad84ba06fd9b96c789dce64cfe939" # replace with your account
```

7. Compile
```shell
$ aptos move compile
```

8. Publish
```shell
$ aptos move publish --profile pancake_multisig_wallet
```

9. Use this package as a base contract and implement your own customized
   multisig wallet to fit your use cases
See `wallets/example` for reference.

## Design
There are three kinds of resource in this contract:
1. Mutlisig Wallet
1. Mutlisig Transactions
1. Events

### Multisig Wallet
Store the owner addresses, the threshold, the sequence number related states and
the signer capability of the resource account.
Owners are the accounts who are authorized to initiate a multisig transaction,
approve a multisig transaction and execute a multisig transaction.
Threshold is the minimum number of owners required to approve a multisig
transaction before it can be executed.
The multisig transactions can only be executed in the strictly greater order of
the sequence number to prevent time rewinding attack.
For example, if the last executed multisig transaction's sequence number is 5,
then all the multisig transactions with sequence number less then 5 are
automatically invalidated, i.e., they can not be executed any longer even if
they have reached the threshold.
Lastly, we have a separate sequence number for owners, representing the current
version of the owners, and will only be incremented when there is a change to
the owners.
For instance, current owners sequence number is 0, we set a new threshold, the
owners sequence number stays 0, we remove an owner from the multisig wallet, the
owners sequence number becomes 1.
Every multisig transaction has its own owners sequence number assigned to the
global one at the moment it's initiated so that if its owners seq number mismatches the global one when executing, it will abort.

### Mutlisig Transactions
Store the multisig transactions of `ParamsType` by a `TableWithLength` with
sequence numbers as keys, e.g., `MutlisigTxs<AddOwnerParams>` store the
transactions which intend to remove an owner from the multisig wallet. Each
multisig transaction stores the parameters, the owners who already approve the
it and whether it has been executed.

To execute a multisig transaction, there are 3 steps:
1. init
1. approve
1. execute

For example, if there are 3 owners: Omelette, JoJo and Snoopy, and the threshold
is 2. Omelette initiate a multisig transaction, JoJo approve the transaction,
now the number of approval reaches 2 (initiation implies approval), which meets
the threshold, allowing the transaction to be executed by any owner, i.e.,
Omelette, JoJo or Snoopy.
Notice that since there are separate resources for each parameters type, the
sequence number in the table may be discrete, and that's why we have a table to
store the mapping of sequence numbers and type names of `ParamsType` so that
users can find the multisig transactions resource corresponding to a given
sequence number.

### Timelock
Every multisig transaction can have a timelock which defines when a multisig
transaction can be executed and when it will be invalidated. There are two
parameters for users to specify:
1. eta
1. expiration

`eta` is the time after which a multisig transaction can be executed, while
`expiration` is the time before which a multisig transaction is valid.

### Events
Store events corresponding to each step of a transaction execution
1. init
1. approve
1. execute

Every event stores the sender and the sequence number so that the tx details can
be queried easily.

# IFO Admin Multisig Wallet
aptos contracts

## Dependence
Aptos CLI

## How to use

1. Initialize the default account
    ```shell
    $ aptos init 
    ```
    you will get a `.aptos` folder in your current folder.
    ```yaml
    profiles:
      default:
        private_key: "0000000000000000000000000000000000000000000000000000000000000000"
        public_key: "0000000000000000000000000000000000000000000000000000000000000000"
        account: 0000000000000000000000000000000000000000000000000000000000000000  // YOUR_ACCOUNT
        rest_url: "https://fullnode.testnet.aptoslabs.com/v1"
        faucet_url: "https://faucet.testnet.aptoslabs.com/"
    ```

2. Get test APT
    ```shell
    $ aptos account fund-with-faucet --account YOUR_ACCOUNT --amount 200000000
    ```

3. Create your resource account
    ```shell
    $ aptos move run --profile default --function-id '0x1::resource_account::create_resource_account_and_fund' --args 'string:pancake-IFO Admin' 'hex:' 'u64:10000000'
    ```

4. Get your resource account
    ```shell
    $ aptos account list --account default
    ```

    Or find it on explorer: https://explorer.testnet.aptos.dev/account/YOUR_ACCOUNT
    
    ```txt
    TYPE:
    0x1::resource_account::Container
    DATA:
    {
      "store": {
        "data": [
          {
            "key": "0xe62fa43ebca8ca2b1a2c6da3b7997888b2ab9cfc0111ed2b85123d5411a91be4",
            "value": {
              "account": "0xe62fa43ebca8ca2b1a2c6da3b7997888b2ab9cfc0111ed2b85123d5411a91be4"  # your resource_account
            }
          }
        ]
      }
    }
    ```

5. Copy the default profile and replace the account with your resource account
    ```yaml
    profiles:
      default:
        private_key: "0000000000000000000000000000000000000000000000000000000000000000"
        public_key: "0000000000000000000000000000000000000000000000000000000000000000"
        account: a1f86fdab3f8c0a7fa0acd7737858dca31bff755f4b33fd87629608818f0327a
        rest_url: "https://fullnode.testnet.aptoslabs.com/v1"
        faucet_url: "https://faucet.testnet.aptoslabs.com/"
      resource_account:
        private_key: "0000000000000000000000000000000000000000000000000000000000000000"
        public_key: "0000000000000000000000000000000000000000000000000000000000000000"
        account: e62fa43ebca8ca2b1a2c6da3b7997888b2ab9cfc0111ed2b85123d5411a91be4
        rest_url: "https://fullnode.testnet.aptoslabs.com/v1"
        faucet_url: "https://faucet.testnet.aptoslabs.com/"
    ```

6. Edit Move.toml file
    ```toml
    [package]
    name = "PancakeIFOMultisigWallet"
    version = "0.0.1"
    
    [dependencies]
    AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "2a458b5ffaaf6a9de6fac679a53912c0be9fe217" }
    AptosStdlib = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-stdlib/", rev = "2a458b5ffaaf6a9de6fac679a53912c0be9fe217" }
    PancakeMultisigWallet = { local = "../../" }
    PancakeIFO = { local = "../../../pancake-IFO" }

    [addresses]
    IFO_multisig_wallet = "0000000000000000000000000000000000000000000000000000000000000000"  // YOUR ACCOUNT
    IFO_multisig_wallet_dev = "0000000000000000000000000000000000000000000000000000000000000000" // YOUR RESOURCE ACCOUNT
    IFO_multisig_wallet_owner1 = "0000000000000000000000000000000000000000000000000000000000000000" 
    IFO_multisig_wallet_owner2 = "0000000000000000000000000000000000000000000000000000000000000000"
    IFO_multisig_wallet_owner3 = "0000000000000000000000000000000000000000000000000000000000000000"
    ```

7. Compile code
    ```shell
    $ aptos move compile
    ```

8. Publish package
    ```shell
    $ aptos move publish --profile resource_account
    ```

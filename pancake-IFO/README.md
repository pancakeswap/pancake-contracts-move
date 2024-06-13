# aptos-contracts IFO
aptos contracts

## Dependence
Aptos CLI

## How to use

1. Initialize the admin account
    ```shell
    $ aptos init --profile IFO_admin
    ```
    you will get a `.aptos` folder in your current folder.
    ```yaml
    profiles:
      IFO_admin:
        private_key: "0000000000000000000000000000000000000000000000000000000000000000"
        public_key: "0000000000000000000000000000000000000000000000000000000000000000"
        account: a1f86fdab3f8c0a7fa0acd7737858dca31bff755f4b33fd87629608818f0327a
        rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
        faucet_url: "https://faucet.devnet.aptoslabs.com/"
    ```

2. Get test APT
    ```shell
    $ aptos account fund-with-faucet --account YOUR_ACCOUNT --amount 200000000
    ```

3. Create your resource account
    ```shell
    $ aptos move run --profile IFO_admin --function-id '0x1::resource_account::create_resource_account_and_fund' --args 'string:pancake-IFO' 'hex:' 'u64:10000000'
    ```

4. Get your resource account
    ```shell
    $ aptos account list --account IFO_admin
    ```

    Or find it on explorer: https://explorer.devnet.aptos.dev/account/YOUR_ACCOUNT
    
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

5. Copy the IFO_admin profile and replace the account with your resource account
    ```yaml
    profiles:
      IFO_admin:
        private_key: "0000000000000000000000000000000000000000000000000000000000000000"
        public_key: "0000000000000000000000000000000000000000000000000000000000000000"
        account: a1f86fdab3f8c0a7fa0acd7737858dca31bff755f4b33fd87629608818f0327a
        rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
        faucet_url: "https://faucet.devnet.aptoslabs.com/"
      resource_account:
        private_key: "0000000000000000000000000000000000000000000000000000000000000000"
        public_key: "0000000000000000000000000000000000000000000000000000000000000000"
        account: e62fa43ebca8ca2b1a2c6da3b7997888b2ab9cfc0111ed2b85123d5411a91be4
        rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
        faucet_url: "https://faucet.devnet.aptoslabs.com/"
    ```

6. Edit Move.toml file
    ```toml
    [package]
    name = "PancakeSwapIFO"
    version = "0.0.1"
    
    [dependencies]
    AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "2a458b5ffaaf6a9de6fac679a53912c0be9fe217" }
    AptosStdlib = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-stdlib/", rev = "2a458b5ffaaf6a9de6fac679a53912c0be9fe217" }
    PancakeSwap = { local = "../pancake-swap" }
    
    [addresses]
    IFO_dev = "_" # repalce this with your IFO_admin
    pancake_IFO = "_" # repalce this with your resource_account
    IFO_default_admin = "_" # repalce this with your admin
    ```

7. Compile code
    ```shell
    $ aptos move compile
    ```

8. Publish package
    ```shell
    $ aptos move publish --profile resource_account
    ```

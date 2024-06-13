# pancake-periphery
Pancake Periphery contracts

## Dependence
Aptos CLI

## How to use

1. Initialize your aptos account
```shell
$ aptos  init
```
you will get a ".aptos" folder in your current folder.
```shell
config.yaml
profiles:
  default:
    private_key: "0x0000000000000000000000000000000000000000000000000000000000000000"
    public_key: "0x0000000000000000000000000000000000000000000000000000000000000000"
    account: 0000000000000000000000000000000000000000000000000000000000000000   # your_original_account
    rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
    faucet_url: "https://faucet.devnet.aptoslabs.com/"
```
2. Get test APT
```shell
$ aptos account  fund-with-faucet --account your_original_account --amount 100000000
```
3. Create your resource account
```shell
$ aptos move run --function-id '0x1::resource_account::create_resource_account_and_fund' --args 'string:any string you want' 'hex:your_original_account' 'u64:10000000'
```
4. Get your resourc eaccount 
```shell
$ aptos account list --account your_original_account
```

Or find it on explorer: https://explorer.devnet.aptos.dev/account/your_original_account

```txt
TYPE:
0x1::resource_account::Container
DATA:
{
  "store": {
    "data": [
      {
        "key": "0x....",
        "value": {
          "account": "0x...."  # your_resource_account
        }
      }
    ]
  }
}
```
5. Replace your_original_account with your_resource_account in config.yaml


6. Edit Move.toml file

  ```shell
[package]
name = "PancakePeriphery"
version = "0.0.1"
[dependencies]
...

[addresses]
pancake_periphery = "...." //repalce this with your_resource_account 
periphery_origin = "....." // repalce this with your_original_account which you created the resource account 
``` 
7. Compile code
```shell
$ aptos move compile
```
8. Publish package
```shell
$ aptos move publish
```
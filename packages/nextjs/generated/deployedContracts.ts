const contracts = {
  31337: [
    {
      name: "arbitrum",
      chainId: "31337",
      contracts: {
        BGTokenFaucet: {
          address: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
          abi: [
            {
              type: "constructor",
              inputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "allowance",
              inputs: [
                {
                  name: "owner",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "spender",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "approve",
              inputs: [
                {
                  name: "spender",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "amount",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "balanceOf",
              inputs: [
                {
                  name: "account",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "decimals",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "uint8",
                  internalType: "uint8",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "decreaseAllowance",
              inputs: [
                {
                  name: "spender",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "subtractedValue",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "increaseAllowance",
              inputs: [
                {
                  name: "spender",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "addedValue",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "name",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "string",
                  internalType: "string",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "requestTokens",
              inputs: [
                {
                  name: "_quantity",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "symbol",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "string",
                  internalType: "string",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "totalSupply",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "transfer",
              inputs: [
                {
                  name: "to",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "amount",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "transferFrom",
              inputs: [
                {
                  name: "from",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "to",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "amount",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "nonpayable",
            },
            {
              type: "event",
              name: "Approval",
              inputs: [
                {
                  name: "owner",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
                {
                  name: "spender",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
                {
                  name: "value",
                  type: "uint256",
                  indexed: false,
                  internalType: "uint256",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "Transfer",
              inputs: [
                {
                  name: "from",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
                {
                  name: "to",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
                {
                  name: "value",
                  type: "uint256",
                  indexed: false,
                  internalType: "uint256",
                },
              ],
              anonymous: false,
            },
          ],
        },
        VaultFactory: {
          address: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
          abi: [
            {
              type: "constructor",
              inputs: [
                {
                  name: "name",
                  type: "string",
                  internalType: "string",
                },
                {
                  name: "governance",
                  type: "address",
                  internalType: "address",
                },
              ],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "acceptGovernance",
              inputs: [],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "apiVersion",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "string",
                  internalType: "string",
                },
              ],
              stateMutability: "pure",
            },
            {
              type: "function",
              name: "deployNewVault",
              inputs: [
                {
                  name: "asset",
                  type: "address",
                  internalType: "contract ERC20",
                },
                {
                  name: "name",
                  type: "string",
                  internalType: "string",
                },
                {
                  name: "symbol",
                  type: "string",
                  internalType: "string",
                },
                {
                  name: "roleManager",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "profitMaxUnlockTime",
                  type: "uint256",
                  internalType: "uint256",
                },
              ],
              outputs: [
                {
                  name: "vaultAddress",
                  type: "address",
                  internalType: "address",
                },
              ],
              stateMutability: "payable",
            },
            {
              type: "function",
              name: "protocolFeeConfig",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "tuple",
                  internalType: "struct VaultFactory.PFConfig",
                  components: [
                    {
                      name: "feeBps",
                      type: "uint16",
                      internalType: "uint16",
                    },
                    {
                      name: "feeRecipient",
                      type: "address",
                      internalType: "address",
                    },
                  ],
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "removeCustomProtocolFee",
              inputs: [
                {
                  name: "vault",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "s_customProtocolFee",
              inputs: [
                {
                  name: "",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "uint16",
                  internalType: "uint16",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "s_defaultProtocolFeeConfig",
              inputs: [],
              outputs: [
                {
                  name: "feeBps",
                  type: "uint16",
                  internalType: "uint16",
                },
                {
                  name: "feeRecipient",
                  type: "address",
                  internalType: "address",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "s_governance",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "address",
                  internalType: "address",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "s_isShutdown",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "s_name",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "string",
                  internalType: "string",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "s_pendingGovernance",
              inputs: [],
              outputs: [
                {
                  name: "",
                  type: "address",
                  internalType: "address",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "s_useCustomProtocolFee",
              inputs: [
                {
                  name: "",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [
                {
                  name: "",
                  type: "bool",
                  internalType: "bool",
                },
              ],
              stateMutability: "view",
            },
            {
              type: "function",
              name: "setCustomProtocolFeeBps",
              inputs: [
                {
                  name: "vault",
                  type: "address",
                  internalType: "address",
                },
                {
                  name: "newCustomFeeBps",
                  type: "uint16",
                  internalType: "uint16",
                },
              ],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "setDefaultProtocolFeeBps",
              inputs: [
                {
                  name: "newFeeBps",
                  type: "uint16",
                  internalType: "uint16",
                },
              ],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "setGovernance",
              inputs: [
                {
                  name: "newGovernance",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "setProtocolFeeRecipient",
              inputs: [
                {
                  name: "newFeeRecipient",
                  type: "address",
                  internalType: "address",
                },
              ],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "function",
              name: "shutdownFactory",
              inputs: [],
              outputs: [],
              stateMutability: "nonpayable",
            },
            {
              type: "event",
              name: "FactoryShutdown",
              inputs: [],
              anonymous: false,
            },
            {
              type: "event",
              name: "NewPendingGovernance",
              inputs: [
                {
                  name: "pendingGovernance",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "NewVault",
              inputs: [
                {
                  name: "vaultAddress",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
                {
                  name: "asset",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "RemoveCustomProtocolFee",
              inputs: [
                {
                  name: "vault",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "UpdateCustomProtocolFee",
              inputs: [
                {
                  name: "vault",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
                {
                  name: "newCustomProtocolFee",
                  type: "uint16",
                  indexed: false,
                  internalType: "uint16",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "UpdateGovernance",
              inputs: [
                {
                  name: "governance",
                  type: "address",
                  indexed: true,
                  internalType: "address",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "UpdateProtocolFeeBps",
              inputs: [
                {
                  name: "oldFeeBps",
                  type: "uint16",
                  indexed: false,
                  internalType: "uint16",
                },
                {
                  name: "newFeeBps",
                  type: "uint16",
                  indexed: false,
                  internalType: "uint16",
                },
              ],
              anonymous: false,
            },
            {
              type: "event",
              name: "UpdateProtocolFeeRecipient",
              inputs: [
                {
                  name: "oldFeeRecipient",
                  type: "address",
                  indexed: false,
                  internalType: "address",
                },
                {
                  name: "newFeeRecipient",
                  type: "address",
                  indexed: false,
                  internalType: "address",
                },
              ],
              anonymous: false,
            },
            {
              type: "error",
              name: "VaultFactory__FeeBpsGtMaxFeeBps",
              inputs: [],
            },
            {
              type: "error",
              name: "VaultFactory__FeeRecipientZeroAddress",
              inputs: [],
            },
            {
              type: "error",
              name: "VaultFactory__IsShutdown",
              inputs: [],
            },
            {
              type: "error",
              name: "VaultFactory__NotGovernance",
              inputs: [],
            },
            {
              type: "error",
              name: "VaultFactory__NotPendingGovernance",
              inputs: [],
            },
          ],
        },
      },
    },
  ],
} as const;

export default contracts;

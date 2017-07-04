DIGITAL DEVELOPERS FUND TOKEN
=====================================================
More info - see https://www.digitaldevelopersfund.com/i


TECH DETAILS GENERAL CHANGES FROM THE BAT ICO CONTRACT
=====================================================

In order to minimise the danger of attack we decided to take existing well audited code and modify it. We took as a baseline the code used in the BAT ICO.

The following changes were implemented

1. Using block times.

The BAT Sale contract uses block start and end numbers instead of block times due to a belief held by Consensys that timestamps can be manipulated by miners. 
https://github.com/ConsenSys/smart-contract-best-practices#timestamp-dependence

Our conversations with ethereum core developers leaves us with the opinion that such manipulations are likely to lead to inaccuracies of no more than a couple of seconds. Comparatively, it is almost impossible to estimate when a block will occur more than a few block into the future which makes a block based ICO a real pain to manage.

This causes changes to the constructor which now calculates the end time by adding <duration> days to the start times.

2. Transfer of tokens updates the splitter contract.

The splitter contract (more info below) needs to know every time that an account’s balance changes. This is coded into a derivative of the transfer function.

3. Last Token Distribution

The BAT contract would reject any deposit that crossed the funding cap. If you were monitoring closely you could get a smaller bid in when an earlier, larger, one had failed. We felt this to be unfair.

Our one modification to the funding part of the contract is, when a deposit is made that crosses the funding cap, to accept the required amount and return the rest.

e.g. if 0.78 ETH are required to finish the sale, on receiving 2 ETH we will allocate 0.78 worth of tokens and return 1.28 ETH.

4. The Splitter

The splitter is a core contract specifically designed to facilitate post-event extraction of token allocation data as of a specific location in time while still permitting data movements during the extraction process.


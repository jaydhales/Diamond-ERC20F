// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";

import "../contracts/facets/ERC20Facet.sol";

import "./helpers/DiamondUtils.sol";

interface Iwrong {
    function nonExist() external view returns (uint256);
}

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20 erc20F;
    ERC20 diamondERC20;

    address reciever = vm.addr(12344);
    address spender = vm.addr(324);

    function setUp() public {
        vm.label(spender, "SPENDER");
        vm.label(reciever, "RECIEVER");
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet), "JayToken", "JAY", 18);
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20F = new ERC20();
        diamondERC20 = ERC20(address(diamond));

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(erc20F),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC20")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function testInvalid() public {
        vm.expectRevert("Diamond: Function does not exist");
        Iwrong(address(diamond)).nonExist();
    }

    function testName() public {
        assertEq(diamondERC20.name(), "JayToken");
    }

    function testSymbol() public {
        assertEq("JAY", diamondERC20.symbol());
    }

    function testDecimals() public {
        assertEq(diamondERC20.decimals(), 18);
    }

    function testMint() public {
        diamondERC20.mint(spender, 10e18);
        assertEq(diamondERC20.totalSupply(), diamondERC20.balanceOf(spender));
    }

    function testApprove() public {
        assertTrue(diamondERC20.approve(spender, 1e18));
        assertEq(diamondERC20.allowance(address(this), spender), 1e18);
    }

    function testTransfer() public {
        testMint();
        vm.startPrank(spender);
        diamondERC20.transfer(reciever, 345);
        assertEq(diamondERC20.balanceOf(reciever), 345);
    }

    function testTransferFrom() external {
        testMint();
        vm.prank(spender);
        diamondERC20.approve(address(this), 1e18);
        assertTrue(diamondERC20.transferFrom(spender, reciever, 0.5e18));
        assertEq(diamondERC20.allowance(spender, address(this)), 1e18 - 0.5e18);
        assertEq(diamondERC20.balanceOf(spender), 10e18 - 0.5e18);
        assertEq(diamondERC20.balanceOf(reciever), 0.5e18);
    }

    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {}
}

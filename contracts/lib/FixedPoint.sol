// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library FixedPoint {
    uint8 private constant RESOLUTION = 112;

    struct uq112x112 {
        uint224 _x;
    }

    struct uq144x112 {
        uint256 _x;
    }

    function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO_FRACTION");
        return uq112x112((uint224(numerator) << RESOLUTION) / denominator);
    }

    function decode144(uq144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> RESOLUTION);
    }

    function mul(uq112x112 memory self, uint256 y) internal pure returns (uq144x112 memory) {
        uint256 z = 0;
        require(y == 0 || (z = self._x * y) / y == self._x, "FixedPoint: MUL_OVERFLOW");
        return uq144x112(z);
    }
}

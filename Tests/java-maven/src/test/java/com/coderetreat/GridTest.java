package com.coderetreat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.*;

class gridtest() {

    @Test
    @DisplayName("Test Grid Initialization")
    void testGridInitialization() {
        Grid grid = new Grid(3, 3);
        State[][] cells = grid.getCells();
        for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
                assertEquals(State.DEAD, cells[i][j], "Cell should be initialized to DEAD");
            }
        }
    }

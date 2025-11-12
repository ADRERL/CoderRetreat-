package com.coderetreat;

public class Grid {
    private State[][] cells;
    
    public Grid(int rows, int cols) {
        cells = new State[rows][cols];
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                cells[i][j] = State.DEAD;
            }
        }
    }

    public State[][] getCells() {
        return cells;
    }

    public void setCells(State[][] cells) {
        this.cells = cells;
    }

}

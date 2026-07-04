# RAT Language Compiler

## Overview
This repository contains an extended compiler for the RAT programming language, implemented in OCaml. RAT is a simple imperative language with a C-like syntax. The compiler translates RAT source code into TAM assembly code, which is designed to run on the TAM virtual machine. 

Initially, the language only supported basic imperative paradigms. This project significantly extends the base compiler to handle more advanced memory and execution concepts.

## Code Example
Here is an example of a `.rat` program demonstrating the extended features in action:

```c
// 1. Enumerated types declaration
enum Operation { Addition, Multiplication, Echange };

// 2. Procedure (void) and pass-by-reference (ref)
void echanger(ref int x, ref int y) {
    int tmp = x;
    x = y;
    y = tmp;
    return;
}

// 3. Pointers and memory allocation
int* initialiserPointeur(int v) {
    int* p = (new int);
    *p = v;
    return p;
}

test {
    int a = 10;
    int b = 5;
    
    // Address assignment
    int* ptrA = &a;
    
    // Procedure call with references
    echanger(ref a, ref b);
    
    // Dereferencing
    print (*ptrA);
}
```

## Features
The base RAT language natively supports booleans, integers, and rationals. We extended the AST and compiler passes to fully support the following features:

* **Pointers:** The language now supports pointers to existing types. This includes pointer initialization, allocation (`new`), memory address access, and dereferencing.
* **Procedures:** Addition of a `void` return type. This allows the creation and invocation of procedures that exist solely to produce side effects.
* **Pass-by-Reference:** Parameters can be passed by reference using the `ref` keyword. This allows the compiler to load the memory address of the variable, enabling direct modifications and side effects on the passed parameters.
* **Enumerated Types:** Custom enumerations can be declared at the top of a `.rat` file before functions. The compiler supports type checking, variable creation, and equality comparisons for these custom types.

## Compiler Architecture
The project is structured around a multi-pass compilation process:
* **Lexing & Parsing:** Analyzes the source code and generates the initial Abstract Syntax Tree (AST).
* **Identifier Management (TDS):** Records variables, functions, and enumerations in the Symbol Table (TDS).
* **Type Checking:** Validates that operations, variable assignments, and procedure calls respect strict typing rules. 
* **Memory Placement:** Computes memory offsets and sizes (e.g., assigning a size of 1 for reference variables).
* **Code Generation:** Translates the validated AST into TAM instructions, adapting memory read/write logic depending on whether a variable is a standard value or a reference.

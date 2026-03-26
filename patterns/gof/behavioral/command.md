# Command Pattern

> Encapsulate a request as an object, thereby letting you parameterize clients with different requests, queue or log requests, and support undoable operations.

## Intent

Turn a request into a stand-alone object containing all information about the request. This transformation lets you pass requests as method arguments, delay or queue a request's execution, and support undoable operations.

## When to Use

- Parameterize objects with operations
- Queue operations for later execution
- Support undo/redo functionality
- Support logging and transactional behavior
- Structure a system around high-level operations built on primitives

## When NOT to Use

- Simple operations with no need for queuing/undo
- Direct method calls are sufficient
- Adding unnecessary indirection

## Structure

```
┌─────────────┐       ┌─────────────┐
│   Invoker   │──────▶│  Command    │ (interface)
└─────────────┘       └──────┬──────┘
                             │
                      ┌──────┴──────┐
                      │ConcreteCommand│
                      └──────┬──────┘
                             │ has
                      ┌──────┴──────┐
                      │  Receiver   │
                      └─────────────┘
```

## Language Examples

### Java

```java
// Command interface
public interface Command {
    void execute();
    void undo();
}

// Receiver - knows how to perform operations
public class TextEditor {
    private StringBuilder content = new StringBuilder();
    private int cursorPosition = 0;

    public void insertText(int position, String text) {
        content.insert(position, text);
        cursorPosition = position + text.length();
    }

    public void deleteText(int position, int length) {
        content.delete(position, position + length);
        cursorPosition = position;
    }

    public String getContent() {
        return content.toString();
    }
}

// Concrete commands
public class InsertTextCommand implements Command {
    private final TextEditor editor;
    private final int position;
    private final String text;

    public InsertTextCommand(TextEditor editor, int position, String text) {
        this.editor = editor;
        this.position = position;
        this.text = text;
    }

    @Override
    public void execute() {
        editor.insertText(position, text);
    }

    @Override
    public void undo() {
        editor.deleteText(position, text.length());
    }
}

public class DeleteTextCommand implements Command {
    private final TextEditor editor;
    private final int position;
    private final int length;
    private String deletedText;  // Saved for undo

    public DeleteTextCommand(TextEditor editor, int position, int length) {
        this.editor = editor;
        this.position = position;
        this.length = length;
    }

    @Override
    public void execute() {
        // Save deleted text for undo
        deletedText = editor.getContent().substring(position, position + length);
        editor.deleteText(position, length);
    }

    @Override
    public void undo() {
        editor.insertText(position, deletedText);
    }
}

// Invoker - stores and executes commands
public class CommandHistory {
    private final Deque<Command> history = new ArrayDeque<>();
    private final Deque<Command> redoStack = new ArrayDeque<>();

    public void execute(Command command) {
        command.execute();
        history.push(command);
        redoStack.clear();  // Clear redo on new command
    }

    public void undo() {
        if (!history.isEmpty()) {
            Command command = history.pop();
            command.undo();
            redoStack.push(command);
        }
    }

    public void redo() {
        if (!redoStack.isEmpty()) {
            Command command = redoStack.pop();
            command.execute();
            history.push(command);
        }
    }
}

// Usage
TextEditor editor = new TextEditor();
CommandHistory history = new CommandHistory();

history.execute(new InsertTextCommand(editor, 0, "Hello"));
history.execute(new InsertTextCommand(editor, 5, " World"));
// Content: "Hello World"

history.undo();  // Content: "Hello"
history.undo();  // Content: ""
history.redo();  // Content: "Hello"
```

### Java (Queued Execution)

```java
// Command for async job processing
public interface Job {
    void execute();
    String getJobId();
    Priority getPriority();
}

// Concrete job
public class EmailJob implements Job {
    private final String jobId;
    private final String to;
    private final String subject;
    private final String body;

    @Override
    public void execute() {
        emailService.send(to, subject, body);
    }

    @Override
    public String getJobId() { return jobId; }

    @Override
    public Priority getPriority() { return Priority.NORMAL; }
}

// Job queue (invoker)
public class JobQueue {
    private final PriorityBlockingQueue<Job> queue;
    private final ExecutorService executor;

    public void submit(Job job) {
        queue.offer(job);
    }

    public void processJobs() {
        while (!Thread.currentThread().isInterrupted()) {
            Job job = queue.take();
            executor.submit(() -> {
                try {
                    job.execute();
                } catch (Exception e) {
                    handleFailure(job, e);
                }
            });
        }
    }
}
```

### Go

```go
// Command interface
type Command interface {
    Execute() error
    Undo() error
}

// Receiver
type Account struct {
    balance float64
}

func (a *Account) Deposit(amount float64) {
    a.balance += amount
}

func (a *Account) Withdraw(amount float64) error {
    if a.balance < amount {
        return errors.New("insufficient funds")
    }
    a.balance -= amount
    return nil
}

// Concrete commands
type DepositCommand struct {
    account *Account
    amount  float64
}

func (c *DepositCommand) Execute() error {
    c.account.Deposit(c.amount)
    return nil
}

func (c *DepositCommand) Undo() error {
    return c.account.Withdraw(c.amount)
}

type WithdrawCommand struct {
    account *Account
    amount  float64
}

func (c *WithdrawCommand) Execute() error {
    return c.account.Withdraw(c.amount)
}

func (c *WithdrawCommand) Undo() error {
    c.account.Deposit(c.amount)
    return nil
}

// Invoker with history
type TransactionManager struct {
    history []Command
}

func (m *TransactionManager) Execute(cmd Command) error {
    if err := cmd.Execute(); err != nil {
        return err
    }
    m.history = append(m.history, cmd)
    return nil
}

func (m *TransactionManager) UndoLast() error {
    if len(m.history) == 0 {
        return errors.New("nothing to undo")
    }
    last := m.history[len(m.history)-1]
    m.history = m.history[:len(m.history)-1]
    return last.Undo()
}

// Usage
account := &Account{balance: 100}
manager := &TransactionManager{}

manager.Execute(&DepositCommand{account: account, amount: 50})   // 150
manager.Execute(&WithdrawCommand{account: account, amount: 30})  // 120
manager.UndoLast()  // 150
```

### Python

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List

# Command interface
class Command(ABC):
    @abstractmethod
    def execute(self) -> None:
        pass

    @abstractmethod
    def undo(self) -> None:
        pass

# Receiver
class Light:
    def __init__(self, location: str):
        self.location = location
        self.is_on = False
        self.brightness = 0

    def on(self) -> None:
        self.is_on = True
        self.brightness = 100
        print(f"{self.location} light is on")

    def off(self) -> None:
        self.is_on = False
        self.brightness = 0
        print(f"{self.location} light is off")

    def dim(self, level: int) -> None:
        self.brightness = level
        print(f"{self.location} light dimmed to {level}%")

# Concrete commands
@dataclass
class LightOnCommand(Command):
    light: Light

    def execute(self) -> None:
        self.light.on()

    def undo(self) -> None:
        self.light.off()

@dataclass
class LightOffCommand(Command):
    light: Light

    def execute(self) -> None:
        self.light.off()

    def undo(self) -> None:
        self.light.on()

@dataclass
class DimCommand(Command):
    light: Light
    level: int
    _previous_level: int = 0

    def execute(self) -> None:
        self._previous_level = self.light.brightness
        self.light.dim(self.level)

    def undo(self) -> None:
        self.light.dim(self._previous_level)

# Macro command - composite
class MacroCommand(Command):
    def __init__(self, commands: List[Command]):
        self._commands = commands

    def execute(self) -> None:
        for cmd in self._commands:
            cmd.execute()

    def undo(self) -> None:
        for cmd in reversed(self._commands):
            cmd.undo()

# Invoker
class RemoteControl:
    def __init__(self):
        self._history: List[Command] = []

    def execute(self, command: Command) -> None:
        command.execute()
        self._history.append(command)

    def undo(self) -> None:
        if self._history:
            command = self._history.pop()
            command.undo()

# Usage
living_room = Light("Living Room")
bedroom = Light("Bedroom")

remote = RemoteControl()
remote.execute(LightOnCommand(living_room))
remote.execute(DimCommand(living_room, level=50))

# Party mode macro
party_on = MacroCommand([
    LightOnCommand(living_room),
    LightOnCommand(bedroom),
    DimCommand(living_room, level=30),
])
remote.execute(party_on)

remote.undo()  # Undoes entire party mode
```

## Review Checklist

### Appropriate Use
- [ ] **[MAJOR]** Need to queue, log, or undo operations
- [ ] **[MAJOR]** Need to parameterize objects with operations
- [ ] **[MINOR]** Building a macro/scripting system

### Correct Implementation
- [ ] **[BLOCKER]** Commands are immutable or capture state for undo
- [ ] **[MAJOR]** Undo captures enough state to reverse operation
- [ ] **[MAJOR]** Commands are self-contained (all needed data included)
- [ ] **[MINOR]** Commands have meaningful names describing action

### Anti-Patterns to Flag
- [ ] **[MAJOR]** Command with no undo when undo is expected
- [ ] **[MAJOR]** Commands that depend on external mutable state
- [ ] **[MINOR]** Using Command when simple method call suffices

## Common Mistakes

### 1. Incomplete Undo State
```java
// BAD: Doesn't save state needed for undo
class MoveCommand implements Command {
    private final Shape shape;
    private final Point newPosition;

    public void execute() {
        shape.moveTo(newPosition);  // Old position lost!
    }

    public void undo() {
        // Can't undo - don't know old position
    }
}

// GOOD: Saves state for undo
class MoveCommand implements Command {
    private final Shape shape;
    private final Point newPosition;
    private Point oldPosition;  // Saved for undo

    public void execute() {
        oldPosition = shape.getPosition();  // Save before
        shape.moveTo(newPosition);
    }

    public void undo() {
        shape.moveTo(oldPosition);  // Restore
    }
}
```

### 2. Command Depends on External State
```java
// BAD: Relies on external state at execution time
class PrintCommand implements Command {
    public void execute() {
        Document doc = DocumentManager.getCurrentDocument();  // External state!
        printer.print(doc);
    }
}

// GOOD: All state captured in command
class PrintCommand implements Command {
    private final Document document;
    private final Printer printer;

    public PrintCommand(Document document, Printer printer) {
        this.document = document;
        this.printer = printer;
    }

    public void execute() {
        printer.print(document);
    }
}
```

## Related Patterns

| Pattern | Relationship |
|---------|-------------|
| **Memento** | Can store state for command undo |
| **Composite** | Macro commands use composite pattern |
| **Strategy** | Both encapsulate algorithms; Command has undo |
| **Prototype** | Commands can be cloned |

## Popular Libraries

| Language | Library | Notes |
|----------|---------|-------|
| **Java** | [Axon Framework](https://www.axoniq.io/) | Command bus with `@CommandHandler` annotations |
| **Java** | [JCIP](https://jcip.net/) | Concurrent command execution patterns |
| **Go** | [Cobra](https://github.com/spf13/cobra) | CLI framework using command pattern |
| **Go** | [urfave/cli](https://github.com/urfave/cli) | Alternative CLI command framework |
| **Python** | [Click](https://click.palletsprojects.com/) | CLI framework built on command pattern |
| **Python** | [Typer](https://typer.tiangolo.com/) | Modern CLI with type hints, built on Click |
| **JavaScript** | [Commander.js](https://github.com/tj/commander.js) | Node.js CLI command framework |
| **JavaScript** | [yargs](https://yargs.js.org/) | CLI argument parsing with command support |
| **.NET** | [MediatR](https://github.com/jbogard/MediatR) | Command/Query dispatch with handlers |
| **.NET** | [Wolverine](https://wolverine.netlify.app/) | Message handling with command pattern |

**Note**: Command pattern is fundamental to CLI frameworks and CQRS implementations. For undo/redo, most applications implement custom command stacks.

## References

- GoF p.233
- Refactoring Guru: https://refactoring.guru/design-patterns/command
- Head First Design Patterns, Chapter 6

"""Test fixture for __init__ and __post_init__ conversion."""

class Person {
    has name: str,
        age: int;

    def init(self: Person, name: str, age: int) {
        self.name = name;
        self.age = age;
    }

    def greet(self: Person) -> str {
        return f"Hello, I'm {self.name}";
    }
}

class Employee(Person) {
    has employee_id: str,
        department: str;

    def init(self: Employee, name: str, age: int, employee_id: str) {
        super.__init__(name, age);
        Person().__init__(name, age);
        self.employee_id = employee_id;
        __init__ = 5;
        print(__init__);
    }

    def postinit(self: Employee) {
        self.department = "Unassigned";
    }
}

obj DataClass {
    has x: int,
        y: int,
        computed: int;

    def postinit {
        self.computed = self.x + self.y;
    }
}

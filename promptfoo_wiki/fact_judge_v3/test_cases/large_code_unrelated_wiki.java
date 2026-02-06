public class UnrelatedContentTest {
    private String name;
    private int age;
    
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
    
    public int getAge() {
        return age;
    }
    
    public void setAge(int age) {
        this.age = age;
    }
    
    public boolean isAdult() {
        return age >= 18;
    }
    
    public String getGreeting() {
        return "Hello, " + name;
    }
    
    public void celebrateBirthday() {
        age++;
    }
    
    public String getLifeStage() {
        if (age < 13) return "Child";
        else if (age < 20) return "Teenager";
        else if (age < 65) return "Adult";
        else return "Senior";
    }
    
    public boolean canVote() {
        return age >= 18;
    }
    
    public boolean canRetire() {
        return age >= 65;
    }
    
    public int yearsToRetirement() {
        return Math.max(0, 65 - age);
    }
}
public class UserRepository {
    public User findById(String id) {
        return mapper.selectById(id);
    }
}
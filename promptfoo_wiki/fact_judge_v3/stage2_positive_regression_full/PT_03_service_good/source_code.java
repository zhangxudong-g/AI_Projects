public class OrderService {
    private final OrderRepository repo;
    public OrderService(OrderRepository repo) { this.repo = repo; }

    public Order find(Long id) {
        return repo.findById(id);
    }
}